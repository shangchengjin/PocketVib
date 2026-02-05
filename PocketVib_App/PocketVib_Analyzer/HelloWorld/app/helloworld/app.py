import toga
from toga.style import Pack
from toga.style.pack import COLUMN, ROW
from toga_iOS.libs import uikit, NSData
from toga_iOS.libs import (
    UIImagePickerController,
    UIImage,
    UIImageView,
    UIViewController,
)
from rubicon.objc import objc_method
from rubicon.objc.api import ObjCInstance
import ctypes
from PIL import ImageFont, ImageDraw, Image
import io
import numpy as np
from helloworld.PocketVib_Vib import vib_extraction


class SpeckleDetailScreen(toga.Box):
    """Screen to display displacement map and frequency spectrum for a specific speckle."""
    def __init__(self, speckle_data, speckle_index):
        super().__init__(style=Pack(direction=COLUMN, padding=10))

        self.add(toga.Label("PocketVib Analyzer", style=Pack(font_size=24, padding=10,font_weight="bold")))
        
        self.speckle_data = speckle_data
        self.speckle_index = speckle_index

        # Speckle Detail Title
        self.add(toga.Label(
            f"Speckle #{self.speckle_index + 1} Detail",
            style=Pack(padding=(10, 5), font_size=20, font_weight="bold")
        ))

        # Displacement Map Section
        self.add(toga.Label(
            "Displacement Map",
            style=Pack(padding=(5, 5), font_size=16, font_weight="bold")
        ))
        self.graph_image_view = toga.ImageView(style=Pack(flex=1, padding=(5, 5), height=200))
        self.add(self.graph_image_view)

        # Frequency Spectrum Section
        self.add(toga.Label(
            "Frequency Spectrum",
            style=Pack(padding=(5, 5), font_size=16, font_weight="bold")
        ))
        self.fft_image_view = toga.ImageView(style=Pack(flex=1, padding=(5, 5), height=200))
        self.add(self.fft_image_view)

        # Generate and display both graphs
        self.visualize_displacement()
        measured_freq = self.visualize_frequency_spectrum()
        
        # Measured Frequency Label
        self.measured_freq_label = toga.Label(
            f"Main Frequency: {measured_freq:.2f} Hz",
            style=Pack(padding=(10, 5), font_size=16, font_weight="bold", text_align="center")
        )
        self.add(self.measured_freq_label)

        # Back Button Section
        back_button_box = toga.Box(style=Pack(direction=COLUMN, alignment='center', padding=(5, 5)))
        
        # Back Button
        back_button = toga.Button(
            "Back",
            on_press=self.go_back,
            style=Pack(padding=(10, 5), font_size=14, width=100)
        )
        back_button_box.add(back_button)
        self.add(back_button_box)
    
    def go_back(self, widget):
        """Navigate back to the main screen."""
        self.window.content = self.window.app.main_box
    def visualize_displacement(self):
        """Generate the time-displacement graph for the speckle."""
        width, height = 800, 400
        graph = Image.new("RGB", (width, height), "white")
        draw = ImageDraw.Draw(graph)
  
        mid_y = height // 2  # Middle of the height for symmetric positive and negative displacement
        draw.line((50, mid_y, width - 50, mid_y), fill="black", width=2)  # X-axis (time)
        draw.line((50, 50, 50, height - 50), fill="black", width=2)  # Y-axis (displacement)

        # Add labels for axes
        try:
            font = ImageFont.truetype("arial.ttf", 14)  # Use a system font
        except IOError:
            font = ImageFont.load_default()  # Fallback to default font if unavailable

        # X-axis label (Time)
        draw.text((width // 2 - 20, mid_y + 20), "Time (ms)", fill="black", font_size=20)
        # Y-axis label (Displacement)
        draw.text((10, 10), "Displacement (pixel)", fill="black",  font_size=20)

        # Add ticks and labels for X-axis (in milliseconds)
        num_ticks_x = 5
        total_time_ms = len(self.speckle_data) * 0.0114  # Total time in milliseconds
        for i in range(num_ticks_x + 1):
            x = 50 + i * (width - 100) // num_ticks_x
            draw.line((x, mid_y - 5, x, mid_y + 5), fill="black", width=2)  # Tick
            time_ms = i * total_time_ms / num_ticks_x
            draw.text((x - 10, mid_y + 10), f"{time_ms:.2f}", fill="black",  font_size=18)  # Label

        # Add ticks and labels for Y-axis (symmetric positive and negative)
        num_ticks_y = 5
        max_displacement = max(np.abs(self.speckle_data))  # Maximum absolute displacement
        for i in range(-num_ticks_y, num_ticks_y + 1):
            y = mid_y - i * (height - 100) // (2 * num_ticks_y)
            draw.line((45, y, 55, y), fill="black", width=2)  # Tick
            value = max_displacement * i / num_ticks_y
            draw.text((0, y - 10), f"{value:.2f}", fill="black", font_size=18)  # Label

        # Normalize data
        x_scale = (width - 100) / len(self.speckle_data)
        y_scale = (height - 100) / (2 * max_displacement) if max_displacement > 0 else 1

        # Plot the speckle data
        for i in range(len(self.speckle_data) - 1):
            x1 = 50 + i * x_scale
            y1 = mid_y - self.speckle_data[i] * y_scale  # Center the displacement around mid_y
            x2 = 50 + (i + 1) * x_scale
            y2 = mid_y - self.speckle_data[i + 1] * y_scale
            draw.line((x1, y1, x2, y2), fill="blue", width=2)

        # Convert the graph to a format Toga can display
        img_bytes = io.BytesIO()
        graph.save(img_bytes, format="PNG")
        img_bytes.seek(0)
        self.graph_image_view.image = toga.Image(src=img_bytes.getvalue())
    def visualize_frequency_spectrum(self):
        """Generate the frequency spectrum graph for the speckle."""
        width, height = 800, 400
        graph = Image.new("RGB", (width, height), "white")
        draw = ImageDraw.Draw(graph)

        # Define margins for the graph
        left_margin = 50
        right_margin = 50
        top_margin = 30
        bottom_margin = 50

        # Draw axes
        draw.line((left_margin, height - bottom_margin, width - right_margin, height - bottom_margin), fill="black", width=2)  # X-axis (Frequency)
        draw.line((left_margin, top_margin, left_margin, height - bottom_margin), fill="black", width=2)  # Y-axis (Amplitude)

        # Add labels for axes
        try:
            font = ImageFont.truetype("arial.ttf", 20)  # Use a system font
        except IOError:
            font = ImageFont.load_default()  # Fallback to default font if unavailable

        # X-axis label (Frequency)
        draw.text((width // 2 - 40, height - bottom_margin + 30), "Frequency (Hz)", fill="black",  font_size=20)
        # Y-axis label (Amplitude)
        draw.text((left_margin - 40, top_margin-30), "Amplitude", fill="black",  font_size=20)

        # Perform FFT and get frequency data
        freq_range = (40, 2000)  # Frequency range in Hz
        fs = 1 / (11.4e-6)  # Sampling frequency

        # FFT calculation
        N = len(self.speckle_data)
        X = np.fft.fft(self.speckle_data, N * 8)  # Zero-padded FFT for better resolution
        f = np.fft.fftfreq(len(X), d=1.0 / fs)  # Frequency values
        f_pos = f[:len(f) // 2]
        A = np.abs(X[:len(f) // 2])  # Amplitude spectrum

        # Filter frequencies to the specified range
        min_freq, max_freq = freq_range
        index_range = np.where((f_pos >= min_freq) & (f_pos <= max_freq))[0]
        f_filtered = f_pos[index_range]
        A_filtered = A[index_range]

        # Normalize data for plotting
        max_amplitude = max(A_filtered)
        measured_freq = f_filtered[np.argmax(A_filtered)]  # Frequency with max amplitude
        peak_index = np.argmax(A_filtered)  # Index of the peak value
        peak_amplitude = A_filtered[peak_index]  # Amplitude of the peak

        # Calculate scaling factors
        x_scale = (width - left_margin - right_margin) / len(f_filtered)
        y_scale = (height - top_margin - bottom_margin) / (max_amplitude * 1.1) if max_amplitude > 0 else 1  # Add 10% padding to Y-axis

        # Add ticks and labels for X-axis
        num_ticks_x = 5
        for i in range(num_ticks_x + 1):
            x = left_margin + i * (width - left_margin - right_margin) // num_ticks_x
            draw.line((x, height - bottom_margin, x, height - bottom_margin + 5), fill="black", width=2)  # Tick
            freq_value = min_freq + i * (max_freq - min_freq) / num_ticks_x
            draw.text((x - 20, height - bottom_margin + 10), f"{freq_value:.0f}", fill="black", font_size=18)  # Label

        # Add ticks and labels for Y-axis
        num_ticks_y = 5
        for i in range(num_ticks_y + 1):
            y = height - bottom_margin - i * (height - top_margin - bottom_margin) // num_ticks_y
            draw.line((left_margin - 5, y, left_margin, y), fill="black", width=2)  # Tick
            value = max_amplitude * i / num_ticks_y
            draw.text((left_margin - 50, y - 10), f"{value:.2f}", fill="black",  font_size=18)  # Label

        # Plot the frequency spectrum
        for i in range(len(f_filtered) - 1):
            x1 = left_margin + i * x_scale
            y1 = height - bottom_margin - A_filtered[i] * y_scale
            x2 = left_margin + (i + 1) * x_scale
            y2 = height - bottom_margin - A_filtered[i + 1] * y_scale
            draw.line((x1, y1, x2, y2), fill="red", width=2)

        # Add a circle to highlight the peak point
        peak_x = left_margin + peak_index * x_scale
        peak_y = height - bottom_margin - peak_amplitude * y_scale
        draw.ellipse(
            [
                (peak_x - 10, peak_y - 10),  # Top-left corner
                (peak_x + 10, peak_y + 10)   # Bottom-right corner
            ],
            outline="red",  # Circle border color
            width=4,        # Circle border thickness
            fill="yellow"   # Fill color of the circle
        )

        # Draw a vertical line from the peak to the X-axis
        draw.line(
            (peak_x, peak_y, peak_x, height - bottom_margin),  # From peak to X-axis
            fill="blue",  # Line color
            width=2       # Line thickness
        )

        # Display measured frequency as text near the circle
        draw.text(
            (peak_x - 50, peak_y - 40),  # Adjust position to be above the circle
            f"{measured_freq:.2f} Hz",
            fill="black",
            font_size=20
        )

        # Convert the graph to a format Toga can display
        img_bytes = io.BytesIO()
        graph.save(img_bytes, format="PNG")
        img_bytes.seek(0)
        self.fft_image_view.image = toga.Image(src=img_bytes.getvalue())

        return measured_freq


class ImagePickerDelegate(UIViewController):
    @objc_method
    def imagePickerController_didFinishPickingMediaWithInfo_(self, picker, info):
        image = info.valueForKey_('UIImagePickerControllerOriginalImage')
        if image:
            data = ObjCInstance(uikit.UIImageJPEGRepresentation(image, 0))
            buf = ctypes.create_string_buffer(data.length)
            ctypes.memmove(ctypes.byref(buf), data.bytes, data.length)

            img = Image.open(io.BytesIO(buf))
            gray_img = img.convert('L')

            self.app.selected_images.append(np.array(gray_img))
            
            thumbnail_height = 100
            aspect_ratio = gray_img.width / gray_img.height
            thumbnail_width = int(thumbnail_height * aspect_ratio)
            
            thumbnail = toga.ImageView(style=Pack(width=thumbnail_width, height=thumbnail_height, padding=(5, 5)))
            img_bytes = io.BytesIO()
            gray_img.save(img_bytes, format='PNG')
            thumbnail.image = toga.Image(src=img_bytes.getvalue())
            self.app.image_scroll_box.add(thumbnail)

            self.app.result_label.text = f"{len(self.app.selected_images)} images selected."

            self.app.frame_counter.text = f"Frames: {len(self.app.selected_images)}"

            self.app.analyze_button.style.visibility = 'visible'

        picker.dismissViewControllerAnimated_completion_(True, None)


class ImagePickerApp(toga.App):    
    def startup(self):
        self.main_box = toga.Box(style=Pack(direction=COLUMN))

        select_button_box = toga.Box(style=Pack(direction=COLUMN, alignment='center', padding=(5, 5)))
        select_button = toga.Button(
            'Select Images', 
            on_press=self.pick_image,
            style=Pack(padding=(0, 0), alignment='center', width=300)
        )
     
        analyze_button_box = toga.Box(style=Pack(direction=COLUMN, alignment='center', padding=(5, 5)))
        self.analyze_button = toga.Button(
            'Vibration Analysis', 
            on_press=self.analyze_vibration,
            style=Pack(padding=(0, 0), alignment='center', width=300)
        )

        clear_button_box = toga.Box(style=Pack(direction=COLUMN, alignment='center', padding=(5, 5)))
        clear_button = toga.Button(
            'Clear Image Stack',
            on_press=self.clear_data,
            style=Pack(padding=(0, 0), alignment='center', width=300)
        )

        image_header_box = toga.Box(style=Pack(direction=ROW, padding=(5, 5)))

        image_list_label = toga.Label("Images Stack", style=Pack(padding=(5, 5)))

        self.frame_counter = toga.Label("Frames: 0", style=Pack(padding=(5, 5)))

        image_header_box.add(image_list_label)
        image_header_box.add(self.frame_counter)

        self.image_scroll_box = toga.Box(style=Pack(direction=ROW, padding=(5, 5)))
        scroll_container = toga.ScrollContainer(horizontal=True, vertical=False)
        scroll_container.content = self.image_scroll_box

        self.result_label = toga.Label('', style=Pack(padding=(10, 5)))

        speckle_label = toga.Label("Speckle List", style=Pack(padding=(5, 5)))

        self.speckle_buttons_box = toga.Box(style=Pack(direction=COLUMN, alignment='center', padding=(10, 5)))
        speckle_scroll = toga.ScrollContainer(horizontal=False, vertical=True)
        speckle_scroll.content = self.speckle_buttons_box
        speckle_scroll.style.update(height=400)

        select_button_box.add(select_button)
        analyze_button_box.add(self.analyze_button)
        clear_button_box.add(clear_button)
        
        self.main_box.add(clear_button_box)
        self.main_box.add(select_button_box)
        self.main_box.add(analyze_button_box)
        self.main_box.add(image_header_box)
        self.main_box.add(scroll_container)
        self.main_box.add(self.result_label)
        self.main_box.add(speckle_label)
        self.main_box.add(speckle_scroll)
        
        self.main_window = toga.MainWindow(title="PocketVib Analyzer")
        self.main_window.content = self.main_box
        self.main_window.show()
        

        self.delegate = ImagePickerDelegate.alloc().init()
        self.delegate.app = self
        
        self.picker = UIImagePickerController.alloc().init()
        self.picker.sourceType = 0
        self.picker.delegate = self.delegate

        self.selected_images = []
        self.speckle_data = []

    def pick_image(self, widget):
        if len(self.selected_images) == 0:
            self.result_label.text = 'Please select images.'
        else:
            self.result_label.text = f"{len(self.selected_images)} images selected."
        
        window = self.main_window._impl.native
        root_view_controller = window.rootViewController
        root_view_controller.presentViewController_animated_completion_(
            self.picker, True, None
        )
    
    def analyze_vibration(self, widget):
    
        if len(self.selected_images) == 0:
            self.result_label.text = "Please select at least 1 image first."
            return

        self.result_label.text = "Processing vibration analysis..."

        try:
            dis_all_speckle, num_speckle, process_time = vib_extraction(self.selected_images)
            process_time = process_time
            self.result_label.text = f"Processing Time Per Frame: {process_time:.2f}"
            if num_speckle > 0 and dis_all_speckle:
                valid_speckles = dis_all_speckle[:num_speckle]
                self.speckle_data = valid_speckles
                self.create_speckle_buttons(valid_speckles, num_speckle)
            else:
                self.result_label.text = "No valid speckles found."

        except Exception as e:
            self.result_label.text = f"Error: {str(e)}"
    def create_speckle_buttons(self, valid_speckles, num_speckle):
        
        self.speckle_buttons_box.children.clear()
        
       
        for i in range(num_speckle):
            if i < len(valid_speckles) and len(valid_speckles[i]) > 0:
                button = toga.Button(
                    f"Speckle {i + 1}",
                    on_press=lambda widget, idx=i: self.navigate_to_speckle(idx),
                    style=Pack(padding=(5, 5), width=200)
                )
                self.speckle_buttons_box.add(button)
                
    def create_speckle_buttons(self, valid_speckles, num_speckle):

        self.speckle_buttons_box.children.clear()
        
        for i in range(num_speckle):
            if i < len(valid_speckles) and len(valid_speckles[i]) > 0:
                button = toga.Button(
                    f"Speckle {i + 1}",
                    on_press=lambda widget, idx=i: self.navigate_to_speckle(idx),  # Bind the current value of i
                    style=Pack(padding=(5, 5), width=200)
                )
                self.speckle_buttons_box.add(button)

    def navigate_to_speckle(self, speckle_index):

        if speckle_index < len(self.speckle_data) and len(self.speckle_data[speckle_index]) > 0:
            speckle_screen = SpeckleDetailScreen(self.speckle_data[speckle_index], speckle_index)
            self.main_window.content = speckle_screen

    def clear_data(self, widget):
        """Reset the app to its initial state by regenerating the UI."""
        # Clear stored data
        self.selected_images.clear()
        self.speckle_data.clear()

        # Reinitialize the main UI layout
        self.main_box = toga.Box(style=Pack(direction=COLUMN))

        # Select Image Button
        select_button_box = toga.Box(style=Pack(direction=COLUMN, alignment="center", padding=(5, 5)))
        select_button = toga.Button(
            "Select Images",
            on_press=self.pick_image,
            style=Pack(padding=(0, 0), alignment="center", width=300),
        )

        # Vibration Analysis Button
        analyze_button_box = toga.Box(style=Pack(direction=COLUMN, alignment="center", padding=(5, 5)))
        self.analyze_button = toga.Button(
            "Vibration Analysis",
            on_press=self.analyze_vibration,
            style=Pack(padding=(0, 0), alignment="center", width=300),  # Initially hidden
        )

        # Clear Data Button
        clear_button_box = toga.Box(style=Pack(direction=COLUMN, alignment="center", padding=(5, 5)))
        clear_button = toga.Button(
            "Clear Image Stack",
            on_press=self.clear_data,
            style=Pack(padding=(0, 0), alignment="center", width=300),
        )


        image_header_box = toga.Box(style=Pack(direction=ROW, padding=(5, 5)))
        
        # Image List Label
        image_list_label = toga.Label("Image Stack", style=Pack(padding=(5, 5)))

        self.frame_counter = toga.Label("Frames: 0", style=Pack(padding=(5, 5)))

        image_header_box.add(image_list_label)
        image_header_box.add(self.frame_counter)

        self.image_scroll_box = toga.Box(style=Pack(direction=ROW, padding=(5, 5)))
        scroll_container = toga.ScrollContainer(horizontal=True, vertical=False)
        scroll_container.content = self.image_scroll_box

        # Result Label
        self.result_label = toga.Label("", style=Pack(padding=(10, 5)))

        # Speckle List Label
        speckle_label = toga.Label("Speckle List", style=Pack(padding=(5, 5)))

        # Vertical Scroll Container for Speckle Buttons
        self.speckle_buttons_box = toga.Box(style=Pack(direction=COLUMN, alignment="center", padding=(10, 5)))
        speckle_scroll = toga.ScrollContainer(horizontal=False, vertical=True)
        speckle_scroll.content = self.speckle_buttons_box
        speckle_scroll.style.update(height=400)

        # Add components to the main box
        select_button_box.add(select_button)
        analyze_button_box.add(self.analyze_button)
        clear_button_box.add(clear_button)  # Add the clear button
        self.main_box.add(clear_button_box)  # Add the clear button box to the UI
        self.main_box.add(select_button_box)
        self.main_box.add(analyze_button_box)
        self.main_box.add(image_header_box)  # Add the header box with label and counter
        self.main_box.add(scroll_container)  # Add the scroll container
        self.main_box.add(self.result_label)
        self.main_box.add(speckle_label)  # Add Speckle List Label
        self.main_box.add(speckle_scroll)  # Add the speckle scroll container

        # Reset the main window content to the new UI
        self.main_window.content = self.main_box



def main():
    return ImagePickerApp('PocketVib Analyzer', 'org.example.vibanalyzer')
