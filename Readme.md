When you hate standing at the clerk's counter, and/or are also too broke for photocopies. 

Quick and dirty, good enough for a ctrl + f tho. Might make a more advanced version that runs in a docker container just so it can be called doxxer-docker. 

**Usage**
- have .jpg images in a directory, preferbly by themselves as this will convert every .jpg present. 

copy doxxer.sh to folder with images to convert. 
```
bash doxxer.sh
```
wait. 
Original version is unchanged, pdf output is saved to a new folder. Output is greyscale 300 dpi. 

**To install dependencies:**

    ImageMagick (for convert):
        Debian/Ubuntu: sudo apt install imagemagick
        macOS (Homebrew): brew install imagemagick

    Tesseract OCR (for tesseract):
        Debian/Ubuntu: sudo apt install tesseract-ocr tesseract-ocr-eng (replace eng with your language, e.g., tesseract-ocr-deu)
        macOS (Homebrew): brew install tesseract tesseract-lang

    img2pdf:
        Debian/Ubuntu: sudo apt install img2pdf
        macOS (Homebrew): brew install img2pdf
        (Alternatively, via Python pip: pip install img2pdf)

    unpaper (if USE_UNPAPER="true" in the script):
        Debian/Ubuntu: sudo apt install unpaper
        macOS (Homebrew): brew install unpaper


Remember to run these commands in your terminal. If you're on a different Linux distribution, the package manager command (e.g., yum, dnf, pacman) and package names might vary slightly.
