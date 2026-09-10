# Panda mark

The panda uses two ears, two eye patches and a small nose with an off-centre drip to the viewer's left. The transparent black master is bundled at `Sources/Panda/Resources/PandaMark.png`.

The native header renders it in white at 23 points. The macOS menu bar uses a 22-point template image so the system supplies the appropriate light or dark colour. The app icon places the same mark on a white rounded tile; it is exported at every standard macOS icon resolution by `scripts/generate-icons.swift` during packaging.

The artwork was generated from the supplied panda reference and refined for Panda. The final master has real alpha transparency: no grey or checkerboard background is included. These files and the README screenshots share the same master artwork.
