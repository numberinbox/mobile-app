import unittest
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]

class NotificationIconTests(unittest.TestCase):
    def test_density_masks(self):
        for density, size in [('mdpi',24),('hdpi',36),('xhdpi',48),('xxhdpi',72),('xxxhdpi',96)]:
            with self.subTest(density=density), Image.open(ROOT / f'android/app/src/main/res/drawable-{density}/notification_icon.png') as image:
                self.assertEqual(image.size, (size,size))
                image = image.convert('RGBA')
                bounds = image.getchannel('A').getbbox()
                self.assertIsNotNone(bounds)
                self.assertGreater(bounds[0], 0)
                self.assertGreater(bounds[1], 0)
                self.assertLess(bounds[2], size)
                self.assertLess(bounds[3], size)
                for r,g,b,a in image.getdata():
                    if a: self.assertEqual((r,g,b), (255,255,255))
                self.assertLessEqual(abs(bounds[0] + bounds[2] - size), 1)
                self.assertLessEqual(abs(bounds[1] + bounds[3] - size), 1)

if __name__ == '__main__': unittest.main()
