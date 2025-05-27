When you hate standing at the clerk's counter, and/or are also too broke for photocopies. 

Quick and dirty, good enough for a ctrl + f tho. Might make a more advanced version that runs in a docker container just so it can be called doxxer-docker. 

**Usage**
- have .jpg images in a directory, preferbly by themselves as this will convert every .jpg present. 

copy doxxer.sh to folder with images to convert. 
```
bash doxxer.sh
```
wait. 
Original version is unchanged, pdf output is saved to a new folder. 

The script uses:

    convert from ImageMagick for image processing

    tesseract for OCR

    img2pdf (Python package) for PDF merging

