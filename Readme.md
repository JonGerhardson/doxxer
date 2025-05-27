When you hate standing at the clerk's counter, and/or are also too broke for photocopies. 

**doxxer.sh** will automatically convert a folder of hastily photographed documents to hastily rotated, cropped, de-skewed PDFs with text (kinda). Does little bit of futzing to straighten the images correctly, but not super duper great on complex forms or super blurry stuff. Defaults to English language, can be changed ion Congifuration block at beginning of script to whatever Tesseract uses. 

Quick and dirty, good enough for a ctrl + f. Not meant as a replacement for anything you'd present or publish unless maybe you're into that. 

Might make a more advanced version that runs in a docker container just so it can be called doxxer-docker. If you're smarter than me at this please make that. I really hate using the scanner app on my phone. 


**Usage**
- have .jpg images in a directory, preferbly by themselves as this will convert every .jpg present. 

copy doxxer.sh to folder with images to convert. 
```
bash doxxer.sh
```
wait. 
Original version is unchanged, pdf output is saved to a new folder. Output is greyscale 300 dpi. 

**Do it faster **

Run jobs in parallel if you have a fast computer by setting the --Iama  or -I flag in your command. 
You can now use doxxer like this:

   ```./doxxer.sh --Iama creep my_images_dir``` will run two jobs in parllel
   
  ```  ./doxxer.sh -I creeeep``` will run four jobs in parlallel

It will try to run as many jobs at once as the number of letter 'e's you enter. 

   ```./doxxer.sh --Iama creeeeeeeeeeeeeeeeeeeep ``` will probably make your computer crash I have not tried it. 

I take no responsibility for anything. Do not use this under any circumstances. Don't try to sue me or I'll cry.

License cc0


**Known issues**
The final step is supposed to combine all the images into one pdf. It doesn't work idk why. If it doensn't work for you run something like 

```
find . -maxdepth 1 -type f -iname "*.pdf" -exec gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=combined_current_dir.pdf {} +
```



**To install dependencies:** (if needed)

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


