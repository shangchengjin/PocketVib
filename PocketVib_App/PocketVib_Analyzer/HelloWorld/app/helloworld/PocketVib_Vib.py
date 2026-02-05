import numpy as np
from PIL import Image, ImageFilter
import time

def find_intervals(mask, flag):
    if flag == 0:
        min = 60
    else:
        min = 100
    intervals = []
    start = None
    for i, value in enumerate(mask):
        if value and start is None:
            start = i
        elif not value and start is not None:
            if (i - 1) - start > min:
                intervals.append((start, i - 1))
            start = None
            
    if start is not None:
        if (len(mask) - 1) - start > min:
            intervals.append((start, len(mask) - 1))
    
    return intervals


def find_shift_subpixel(image):
    dis = [0]
    means = np.mean(image, axis=1, keepdims=True)
    stds = np.std(image, axis=1, keepdims=True)
    image = (image - means) / (stds+1e-6)
   
    for row in range(image.shape[0] - 1):
        current = image[row]
        next_row = image[row+1]
        correlation = np.correlate(current, next_row, mode='full')
        max_index = np.argmax(correlation)
        shift = max_index - (len(current) - 1)
        
        
        if 1 <= max_index <= len(correlation) - 2:
            R_m1 = correlation[max_index - 1]
            R_0 = correlation[max_index]
            R_p1 = correlation[max_index + 1]
            
            denominator = R_m1 - 2 * R_0 + R_p1
            if denominator != 0:
                subpixel_offset = 0.5 * (R_m1 - R_p1) / denominator
                shift += subpixel_offset
        
        dis.append(shift)
    
    return np.array(dis)

def detect_peaks_with_width(signal, height_threshold, min_distance):
    signal = np.array(signal)
    
    baseline = np.median(signal)
    signal_range = np.max(signal) - baseline
    threshold = baseline + height_threshold * signal_range

    peaks = []
    for i in range(1, len(signal) - 1):
        if signal[i] > signal[i - 1] and signal[i] > signal[i + 1] and signal[i] >= threshold:
            peaks.append(i)

    if len(peaks) > 1:
        filtered_peaks = [peaks[0]]
        for p in peaks[1:]:
            if p - filtered_peaks[-1] >= min_distance:
                filtered_peaks.append(p)
        peaks = filtered_peaks

    intervals = []
    for i, peak in enumerate(peaks):
        left = peak
        right = peak
        peak_height = signal[peak]
        half_height = baseline + (peak_height - baseline) / 2

        left_limit = 0
        right_limit = len(signal) - 1
        if i > 0:
            left_limit = (peaks[i - 1] + peak) // 2
        if i < len(peaks) - 1:
            right_limit = (peak + peaks[i + 1]) // 2

        while left > left_limit:
            if signal[left - 1] <= half_height:
                break
            left -= 1

        while right < right_limit:
            if signal[right + 1] <= half_height:
                break
            right += 1

        intervals.append((left, right))

    return intervals

def gaussian_kernel(sigma, kernel_size=None):

    if kernel_size is None:
  
        kernel_size = int(np.ceil(sigma * 6))
        if kernel_size % 2 == 0:
            kernel_size += 1
    
    x = np.arange(-(kernel_size // 2), kernel_size // 2 + 1)
    
    kernel = np.exp(-(x**2) / (2 * sigma**2))
    
    kernel = kernel / np.sum(kernel)
    
    return kernel

def gaussian_filter1d(arr, sigma=1):

    kernel = gaussian_kernel(sigma)
    
    pad_width = len(kernel) // 2
    
    padded = np.pad(arr, pad_width, mode='edge')
    
    filtered = np.convolve(padded, kernel, mode='valid')
    
    return filtered

def lowpass_filter(signal, cutoff_freq, fs, order=3):

    N = len(signal)
    
    signal_fft = np.fft.rfft(signal)
    
    freqs = np.fft.rfftfreq(N, d=1/fs)
    
    norm_cutoff = cutoff_freq / (fs/2)

    h = 1.0 / (1.0 + (freqs/(norm_cutoff*fs/2))**(2*order))
    
    filtered_fft = signal_fft * h
    
    filtered_signal = np.fft.irfft(filtered_fft, n=N)
    
    return filtered_signal

def adaptive_ar_interpolation(signal, single_point_segment_index, ar_order=None, max_iterations=3):

    dis = np.zeros_like(signal)
    
    signal = signal[single_point_segment_index[0][0]:single_point_segment_index[1][1]]
    missing_indices = np.where(signal == 0)[0]

    signal_filled = np.array(signal, dtype=np.float64)

    if ar_order is None:
        ar_order = 3 * len(missing_indices) + 2

    signal_filled[missing_indices] = 0.0

    for iteration in range(max_iterations):
        known_indices = np.where(signal_filled != 0)[0]
        known_signal = signal_filled[known_indices]
        
        if len(known_signal) <= ar_order:
            raise ValueError("Not enough known samples to estimate AR parameters.")

        X = np.zeros((len(known_signal) - ar_order, ar_order))
        y = np.zeros(len(known_signal) - ar_order)
        
        for i in range(ar_order, len(known_signal)):
            X[i - ar_order] = known_signal[i - ar_order:i][::-1]
            y[i - ar_order] = known_signal[i]
        
        try:
            ar_params = np.linalg.lstsq(X, y, rcond=None)[0]
        except np.linalg.LinAlgError:
            XTX = X.T @ X
            reg = 0.01 * np.eye(XTX.shape[0])
            ar_params = np.linalg.inv(XTX + reg) @ X.T @ y

        def create_toeplitz(col, row=None):
            if row is None:
                row = np.r_[col[0], np.zeros(len(col) - 1)]
            
            n_col = len(col)
            n_row = len(row)
            
            result = np.zeros((n_row, n_col))
            
            for i in range(n_row):
                for j in range(n_col):
                    if i - j >= 0:
                        result[i, j] = col[i - j]
                    else:
                        result[i, j] = row[j - i]
            
            return result


        toeplitz_col = np.zeros(ar_order)
        toeplitz_col[:len(ar_params)] = ar_params
        B_matrix = create_toeplitz(toeplitz_col)

        for idx in missing_indices:

            start_idx = max(0, idx - ar_order)
            end_idx = idx
            context_indices = np.arange(start_idx, end_idx)

            context_values = signal_filled[context_indices]
            if len(context_values) < ar_order:
                context_values = np.pad(context_values, (ar_order - len(context_values), 0), mode='constant')

            interpolated_value = np.dot(ar_params[:len(context_values)], context_values[::-1])
            signal_filled[idx] = interpolated_value
    
    dis[single_point_segment_index[0][0]:single_point_segment_index[1][1]] = signal_filled
    
    return dis
def vib_extraction(image_list):
    dis_all_speckle = [[] for _ in range(10)]
    T = 11.4e-6
    fs = int(1/T)
    start_time = time.time()
    for experiment in range(1):
        for id in range(len(image_list)):
            image = image_list[id]
            img_data_ROI = image.copy()
            col_intensity = np.average(img_data_ROI, axis=0)
            filtered_col = gaussian_filter1d(col_intensity, sigma=20)
            peaks_col = detect_peaks_with_width(filtered_col, height_threshold=0.1, min_distance=100)
            row_intensity = np.average(img_data_ROI, axis=1)
            filtered_row = gaussian_filter1d(row_intensity,sigma=10)
            
            global_mean = np.mean(filtered_row)
            global_std = np.std(filtered_row)
            local_adjustment = np.percentile(filtered_row, 90) - np.percentile(filtered_row, 10)
            threshold = global_mean - 0.2 * global_std + 0.1 * local_adjustment
            above_threshold = filtered_row > threshold
            peaks_row = find_intervals(above_threshold, 1)
            if len(peaks_row) >= 3:
                peaks_row = sorted(peaks_row, key=lambda x: (-(x[1] - x[0]), x[0]))[:2]
                peaks_row = sorted(peaks_row, key=lambda x: x[0])        
            height, width = image.shape
            num_speckle = len(peaks_col)
            for i in range(num_speckle):
                dis = np.zeros(height)
                for j in range(2):
                    i_speckle_img = image[peaks_row[j][0]:peaks_row[j][1], peaks_col[i][0]:peaks_col[i][1]]
                    pil_img = Image.fromarray(i_speckle_img.astype(np.uint8))
                    filtered_pil_img = pil_img.filter(ImageFilter.MedianFilter(size=7))
                    i_speckle_img = np.array(filtered_pil_img)
                    dis_tmp = find_shift_subpixel(i_speckle_img)
                    dis_tmp = lowpass_filter(dis_tmp, 2000, fs, order=3)
                    dis[peaks_row[j][0]:peaks_row[j][1]] = dis_tmp
                dis = adaptive_ar_interpolation(dis, peaks_row, ar_order=None, max_iterations=1)
                dis = np.concatenate((dis, np.zeros(int((1/30 - height*T)/T)-1)))
                dis_all_speckle[i].extend(dis)
    process_time = (time.time() - start_time)
    return dis_all_speckle, num_speckle, process_time
