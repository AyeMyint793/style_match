import io
import numpy as np
from PIL import Image, ImageEnhance, ImageOps, ImageFilter
from rembg import remove, new_session
import scipy.ndimage as ndi

class ImageService:
    _rembg_session = None

    @classmethod
    def get_rembg_session(cls):
        if cls._rembg_session is None:
            try:
                cls._rembg_session = new_session("u2netp")
            except Exception:
                try:
                    cls._rembg_session = new_session("u2net")
                except Exception:
                    cls._rembg_session = None
        return cls._rembg_session

    @staticmethod
    def load_image_from_bytes(image_bytes: bytes) -> Image.Image:
        """
        Loads an image from raw bytes, correctly handling EXIF orientation and RGB mode.
        """
        img = Image.open(io.BytesIO(image_bytes))
        img = ImageOps.exif_transpose(img)
        if img.mode not in ("RGB", "RGBA"):
            img = img.convert("RGB")
        return img

    @staticmethod
    def enhance_image(img: Image.Image) -> Image.Image:
        """
        Enhances image quality by adjusting contrast, brightness, and sharpness.
        """
        if img.mode != "RGB" and img.mode != "RGBA":
            img = img.convert("RGB")
        
        # 1. Auto-contrast normalization
        try:
            if img.mode == "RGBA":
                r, g, b, a = img.split()
                rgb_img = Image.merge("RGB", (r, g, b))
                rgb_img = ImageOps.autocontrast(rgb_img, cutoff=1)
                r2, g2, b2 = rgb_img.split()
                img = Image.merge("RGBA", (r2, g2, b2, a))
            else:
                img = ImageOps.autocontrast(img, cutoff=1)
        except Exception:
            pass
        
        # 2. Brightness adjustment (boost if image is dark)
        try:
            gray = img.convert("L")
            avg_brightness = float(np.mean(np.array(gray)))
            if avg_brightness < 110:
                boost = 1.0 + min(0.35, (110.0 - avg_brightness) / 190.0)
                img = ImageEnhance.Brightness(img).enhance(boost)
        except Exception:
            pass
            
        # 3. Contrast adjustment
        img = ImageEnhance.Contrast(img).enhance(1.12)
        
        # 4. Sharpness enhancement
        img = ImageEnhance.Sharpness(img).enhance(1.25)
        
        return img

    @classmethod
    def remove_background(cls, img: Image.Image, category: str = "Tops") -> Image.Image:
        """
        Removes the background using rembg U2-Net, returning an RGBA transparent image.
        Also applies background color rejection to clear internal gaps (e.g. inseam bedsheet triangle).
        """
        try:
            orig_w, orig_h = img.size
            max_dim = max(orig_w, orig_h)
            
            working_img = img
            if max_dim > 1024:
                scale = 1024.0 / max_dim
                working_img = img.resize((int(orig_w * scale), int(orig_h * scale)), Image.Resampling.LANCZOS)
            
            session = cls.get_rembg_session()
            if session is not None:
                result = remove(working_img, session=session)
            else:
                result = remove(working_img)

            if (orig_w, orig_h) != result.size:
                result = result.resize((orig_w, orig_h), Image.Resampling.LANCZOS)

            # Check if mask is valid (not empty or destroyed)
            if result.mode == "RGBA":
                alpha = np.array(result.split()[-1])
                visible_ratio = np.count_nonzero(alpha > 20) / float(alpha.size)
                
                if visible_ratio < 0.05:
                    print(f"[ImageService] Background removal yielded low visible ratio ({visible_ratio:.3f}), retaining clean crop")
                    return img.convert("RGBA")

            cat_lower = (category or "").lower()
            is_top_like = any(
                key in cat_lower
                for key in ["top", "shirt", "tee", "crop", "camisole", "tank", "blouse", "dress"]
            )

            # Targeted background surface rejection for internal gaps (e.g. inseam of jeans).
            # Sample only the outer corners to avoid capturing garment borders.
            rgb_arr = np.array(img.convert("RGB")).astype(float)
            rgba_arr = np.array(result.convert("RGBA"))
            r, g, b, a = rgba_arr[:, :, 0], rgba_arr[:, :, 1], rgba_arr[:, :, 2], rgba_arr[:, :, 3]
            h, w, _ = rgb_arr.shape
            
            cw = max(3, int(w * 0.07))
            ch = max(3, int(h * 0.07))
            corner_samples = np.vstack([
                rgb_arr[:ch, :cw].reshape(-1, 3),
                rgb_arr[:ch, w - cw:].reshape(-1, 3),
                rgb_arr[h - ch:, :cw].reshape(-1, 3),
                rgb_arr[h - ch:, w - cw:].reshape(-1, 3),
            ])
            
            # Only apply color rejection if corner background has a clear identifiable color
            # and avoid applying it to tops/camisoles where delicate fabrics can be mistaken for background
            if len(corner_samples) > 16 and not is_top_like:
                bg_median = np.median(corner_samples, axis=0)
                bg_std = np.std(corner_samples, axis=0) + 14.0
                dist_to_bg = np.sqrt(np.sum(((rgb_arr - bg_median) / bg_std) ** 2, axis=-1))
                
                # Only clear pixels that are extremely close to the corner background color
                # and where alpha is already somewhat uncertain (alpha < 220)
                is_bg_color = (dist_to_bg < 1.75) & (a < 220)
                a = np.where(is_bg_color, 0, a)

            return Image.merge("RGBA", (
                Image.fromarray(r),
                Image.fromarray(g),
                Image.fromarray(b),
                Image.fromarray(a.astype(np.uint8))
            ))
        except Exception as e:
            print(f"[ImageService] Background removal failed, using authentic crop: {e}")
            return img.convert("RGBA")

    @staticmethod
    def clean_alpha_mask(img: Image.Image, category: str = "Tops") -> Image.Image:
        """
        Applies morphological operations on the alpha channel:
        - Removes disconnected background noise / stray bedsheet speckles
        - Prunes intruder garment fragments from touching adjacent clothes (e.g. top straps on jeans waistband)
        - Fills small holes in garment interior texture
        - Feathers edges smoothly for studio catalog quality
        """
        if img.mode != "RGBA":
            img = img.convert("RGBA")
            
        r, g, b, a = img.split()
        alpha_arr = np.array(a)
        h, w = alpha_arr.shape
        
        cat_lower = (category or "").lower()
        is_bottoms = cat_lower in ["bottoms"] or any(k in cat_lower for k in ["pant", "jean", "trouser", "short", "skirt"])
        is_tops = cat_lower in ["tops"] or any(k in cat_lower for k in ["top", "shirt", "tee", "crop", "camisole", "tank", "blouse", "sweater", "hoodie"])

        # 1. Threshold cutoff: Tops need a gentle threshold to preserve delicate straps & grey fabric
        alpha_bin = alpha_arr > (16 if is_tops else 40)
        
        # 2. Morphological opening to disconnect thin noise bridges
        struct = np.ones((1, 1)) if is_tops else np.ones((3, 3))
        opened_bin = ndi.binary_opening(alpha_bin, structure=struct)
        
        labeled, num_features = ndi.label(opened_bin)
        if num_features > 1:
            sizes = ndi.sum(opened_bin, labeled, range(1, num_features + 1))
            dominant_label = np.argmax(sizes) + 1
            dominant_size = sizes[dominant_label - 1]
            
            objects = ndi.find_objects(labeled)
            valid_labels = [dominant_label]
            
            for i, sl in enumerate(objects):
                lbl = i + 1
                if lbl == dominant_label or sl is None:
                    continue
                
                comp_size = sizes[i]
                y_slice, x_slice = sl
                
                # For Bottoms: prune intruder top garment fragments at the very top of crop
                if is_bottoms and y_slice.stop < h * 0.22:
                    print(f"[ImageService] Pruned intruder top garment fragment at y={y_slice} from {category} crop")
                    continue
                    
                # For Tops: prune intruder bottoms fragments at the very bottom of crop
                if is_tops and y_slice.start > h * 0.80:
                    print(f"[ImageService] Pruned intruder bottoms fragment at y={y_slice} from {category} crop")
                    continue
                    
                # Keep significant secondary components (e.g. separated pant legs, straps, collar details)
                keep_ratio = 0.008 if is_tops else 0.04
                if comp_size >= dominant_size * keep_ratio:
                    valid_labels.append(lbl)
                    
            keep_mask = np.isin(labeled, valid_labels)
            keep_mask_dilated = ndi.binary_dilation(keep_mask, structure=struct)
            alpha_arr = np.where(keep_mask_dilated & (alpha_arr > (14 if is_tops else 30)), alpha_arr, 0)
        else:
            alpha_arr = np.where(alpha_bin, alpha_arr, 0)
        
        # 3. Morphological closing to fill small fabric gaps and knit texture
        close_struct = np.ones((3, 3)) if is_tops else np.ones((4, 4))
        closed_bin = ndi.binary_closing(alpha_arr > (18 if is_tops else 35), structure=close_struct)
        alpha_arr = np.where(closed_bin, np.maximum(alpha_arr, 215), alpha_arr)
        
        # 4. Smooth feathering on edges for studio catalog presentation
        alpha_float = alpha_arr.astype(float)
        smoothed = ndi.gaussian_filter(alpha_float, sigma=0.55)
        cleaned_alpha = np.clip(smoothed, 0, 255).astype(np.uint8)
        
        return Image.merge("RGBA", (r, g, b, Image.fromarray(cleaned_alpha)))

    @staticmethod
    def mask_quality(img: Image.Image) -> dict:
        """
        Returns simple sanity metrics for the alpha mask so we can avoid saving
        shredded crops when segmentation fails.
        """
        if img.mode != "RGBA":
            img = img.convert("RGBA")

        alpha = np.array(img.split()[-1])
        visible = alpha > 30
        visible_pixels = int(np.count_nonzero(visible))
        visible_ratio = visible_pixels / float(alpha.size)

        labeled, component_count = ndi.label(visible)
        if component_count == 0 or visible_pixels == 0:
            return {
                "visible_ratio": visible_ratio,
                "component_count": int(component_count),
                "largest_component_ratio": 0.0,
            }

        sizes = ndi.sum(visible, labeled, range(1, component_count + 1))
        largest_component_ratio = float(np.max(sizes)) / float(visible_pixels)
        return {
            "visible_ratio": visible_ratio,
            "component_count": int(component_count),
            "largest_component_ratio": largest_component_ratio,
        }

    @staticmethod
    def should_use_original_crop_fallback(processed: Image.Image, original_crop: Image.Image, category: str = "Tops") -> bool:
        quality = ImageService.mask_quality(processed)
        original_area = float(max(original_crop.size[0] * original_crop.size[1], 1))
        processed_alpha = np.array(processed.convert("RGBA").split()[-1])
        retained_ratio = np.count_nonzero(processed_alpha > 30) / original_area

        unreliable = (
            quality["visible_ratio"] < 0.04
            or retained_ratio < 0.035
            or (
                quality["component_count"] >= 8
                and quality["largest_component_ratio"] < 0.55
            )
        )
        if unreliable:
            print(
                f"[ImageService] Mask unreliable for {category}; using original full-resolution crop "
                f"instead of shredded fragments. quality={quality}, retained_ratio={retained_ratio:.3f}"
            )
        return unreliable

    @staticmethod
    def normalize_orientation(img: Image.Image, category: str = "Tops") -> Image.Image:
        """
        Intelligently corrects garment orientation (e.g. horizontally laid jeans/dresses).
        """
        if img.mode != "RGBA":
            img = img.convert("RGBA")
            
        bbox = img.getbbox()
        if not bbox:
            return img
            
        w = bbox[2] - bbox[0]
        h = bbox[3] - bbox[1]
        
        cat_lower = (category or "").lower()
        # Bottoms (jeans, pants), dresses, and long coats are naturally tall
        if cat_lower in ["bottoms", "dress"] or "pant" in cat_lower or "jean" in cat_lower or "trousers" in cat_lower or "skirt" in cat_lower:
            if w > 1.35 * h:
                print(f"[ImageService] Rotating horizontally oriented {category} to vertical presentation...")
                return img.rotate(90, expand=True, resample=Image.Resampling.BICUBIC)
                
        return img

    @staticmethod
    def crop_and_normalize_to_square(img: Image.Image, canvas_size: int = 800, max_fill_ratio: float = 0.84) -> Image.Image:
        """
        Trims excess transparent borders and scales the garment so it occupies
        a consistent, beautiful proportion (~84%) centered on a transparent square canvas.
        """
        if img.mode != "RGBA":
            img = img.convert("RGBA")
            
        bbox = img.getbbox()
        if not bbox:
            return img.resize((canvas_size, canvas_size))
            
        trimmed = img.crop(bbox)
        tw, th = trimmed.size
        
        # Scale proportionally to fit within max_fill_ratio of canvas
        target_max = int(canvas_size * max_fill_ratio)
        scale = target_max / float(max(tw, th))
        new_w = max(1, int(tw * scale))
        new_h = max(1, int(th * scale))
        
        scaled = trimmed.resize((new_w, new_h), Image.Resampling.LANCZOS)
        
        # Symmetrically center onto transparent square canvas
        canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        paste_x = (canvas_size - new_w) // 2
        paste_y = (canvas_size - new_h) // 2
        canvas.paste(scaled, (paste_x, paste_y), scaled)
        
        return canvas

    @staticmethod
    def crop_bounding_box(img: Image.Image, box_2d: list, margin_ratio: float = 0.04) -> Image.Image:
        """
        Crops a sub-region from an image given a 2D bounding box [ymin, xmin, ymax, xmax].
        Supports normalized (0.0-1.0), millinormalized (0-1000), or absolute pixel coordinates.
        """
        w, h = img.size
        if not box_2d or len(box_2d) != 4:
            return img

        y1, x1, y2, x2 = float(box_2d[0]), float(box_2d[1]), float(box_2d[2]), float(box_2d[3])
        ymin, ymax = min(y1, y2), max(y1, y2)
        xmin, xmax = min(x1, x2), max(x1, x2)

        # Normalize coordinates to 0.0 - 1.0 range
        max_val = max(ymin, xmin, ymax, xmax)
        if max_val > 1.0:
            if max_val <= 1000.0:
                ymin, xmin, ymax, xmax = ymin / 1000.0, xmin / 1000.0, ymax / 1000.0, xmax / 1000.0
            else:
                ymin, xmin, ymax, xmax = ymin / float(h), xmin / float(w), ymax / float(h), xmax / float(w)

        # Clamp normalized coordinates to [0.0, 1.0]
        ymin = max(0.0, min(1.0, ymin))
        xmin = max(0.0, min(1.0, xmin))
        ymax = max(0.0, min(1.0, ymax))
        xmax = max(0.0, min(1.0, xmax))

        # Add adaptive margin so garment edges, sleeves, and collars are not clipped
        box_w = max(0.01, xmax - xmin)
        box_h = max(0.01, ymax - ymin)
        margin_x = max(box_w * margin_ratio, 0.02)
        margin_y = max(box_h * margin_ratio, 0.02)

        left = max(0, int((xmin - margin_x) * w))
        top = max(0, int((ymin - margin_y) * h))
        right = min(w, int((xmax + margin_x) * w))
        bottom = min(h, int((ymax + margin_y) * h))

        if right <= left or bottom <= top:
            return img

        return img.crop((left, top, right, bottom))

    @classmethod
    def process_clothing_image(cls, image_bytes: bytes, category: str = "Tops") -> bytes:
        """
        Full single-image pipeline: Loads, enhances, removes background, cleans alpha mask,
        normalizes orientation, crops/centers to square canvas, and returns PNG bytes.
        """
        raw_img = cls.load_image_from_bytes(image_bytes)
        enhanced = cls.enhance_image(raw_img)
        transparent = cls.remove_background(enhanced, category=category)
        cleaned = cls.clean_alpha_mask(transparent, category=category)
        if cls.should_use_original_crop_fallback(cleaned, raw_img, category):
            cleaned = raw_img.convert("RGBA")
        oriented = cls.normalize_orientation(cleaned, category=category)
        final_canvas = cls.crop_and_normalize_to_square(oriented, canvas_size=800, max_fill_ratio=0.84)
        
        output_buffer = io.BytesIO()
        final_canvas.save(output_buffer, format="PNG", optimize=True)
        return output_buffer.getvalue()

    @classmethod
    def process_multi_item_crop(cls, raw_img: Image.Image, box_2d: list, category: str = "Tops") -> bytes:
        """
        Crops an individual item from a multi-item photo, enhances, segments, cleans,
        normalizes orientation, and returns studio-quality square transparent PNG bytes.
        """
        if hasattr(raw_img, "_getexif"):
            raw_img = ImageOps.exif_transpose(raw_img)

        cropped = cls.crop_bounding_box(raw_img, box_2d, margin_ratio=0.035)
        enhanced = cls.enhance_image(cropped)
        transparent = cls.remove_background(enhanced, category=category)
        cleaned = cls.clean_alpha_mask(transparent, category=category)
        if cls.should_use_original_crop_fallback(cleaned, cropped, category):
            cleaned = cropped.convert("RGBA")
        oriented = cls.normalize_orientation(cleaned, category=category)
        final_canvas = cls.crop_and_normalize_to_square(oriented, canvas_size=800, max_fill_ratio=0.84)

        output_buffer = io.BytesIO()
        final_canvas.save(output_buffer, format="PNG", optimize=True)
        return output_buffer.getvalue()

    # Safety aliases for backward compatibility
    process_single_image = process_clothing_image
    crop_and_pad_to_square = crop_and_normalize_to_square
