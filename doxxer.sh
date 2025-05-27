#!/bin/bash

# --- Configuration ---
OCR_LANG="eng"                     # OCR language (ensure Tesseract pack is installed, e.g., eng, deu, fra, spa)
INPUT_DIR="."                      # Default input directory, can be overridden by command-line argument
OUTPUT_DIR_BASE="ocr_processed_output" # Main output directory for all processed files
PROCESSED_IMG_DIR="${OUTPUT_DIR_BASE}/intermediate_images" # Subdirectory for intermediate processed images (PNGs)
INDIVIDUAL_PDF_DIR="${OUTPUT_DIR_BASE}/individual_pdfs"    # Subdirectory for individual OCR'd PDFs
COMBINED_PDF_NAME="Combined_OCR_Document.pdf"              # Final combined PDF name
DESKEW_PERCENT="40%"               # Deskew intensity (ImageMagick -deskew argument)
TRIM_FUZZ="5%"                     # Trim fuzz percentage (ImageMagick -fuzz argument for -trim)
CLEANUP_INTERMEDIATE="true"        # Cleanup intermediate files: "true" or "false"
USE_GPU="false"                    # Attempt to use GPU for Tesseract: "true" or "false".
                                   # Requires Tesseract 5+ compiled with OpenCL support.
USE_UNPAPER="false"                # Use 'unpaper' for advanced deskewing/cleaning: "true" or "false".
                                   # Requires 'unpaper' to be installed.
UNPAPER_OPTIONS="--dpi 300"        # Default options for unpaper. Can be overridden.
AUTO_ROTATE_VIA_OSD="true"         # Use Tesseract OSD for auto-rotation (90/180/270 deg): "true" or "false".
                                   # Requires tesseract-ocr-osd (osd.traineddata).
USE_PARALLEL_PROCESSING="true"     # Use GNU Parallel for processing images: "true" or "false"
PARALLEL_JOBS="0"                  # Default number of parallel jobs for GNU Parallel.
                                   # "0" means one job per CPU core. "4" means 4 jobs.
                                   # Can be overridden by -I/--Iama flag.

# --- Functions ---

# Function to display usage instructions
usage() {
  echo "Usage: ${0} [options] [input_directory]"
  echo ""
  echo "Processes JPG/JPEG images in the specified directory (or current directory if none given)"
  echo "into a single, searchable PDF document."
  echo "Output will be in '${OUTPUT_DIR_BASE}/'."
  echo ""
  echo "Options:"
  echo "  -I, --Iama <job_specifier>  Set parallel jobs based on the number of 'e's (case-insensitive)"
  echo "                              in <job_specifier>. Example: --Iama 'creeep' sets 4 parallel jobs."
  echo "                              This enables parallel processing if job count > 0."
  echo "  -h, --help                  Display this help message and exit."
  echo ""
  echo "Configuration variables at the top of the script can also be modified for default behavior."
  exit 1
}

# --- Argument Parsing (Overrides Configuration Defaults) ---
# Initialize variables that might be set by flags
NEW_PARALLEL_JOBS_VALUE=""
NEW_INPUT_DIR_VALUE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -I|--Iama)
            if [[ -n "$2" ]]; then
                JOB_SPECIFIER="$2"
                # Count 'e's (case-insensitive), remove whitespace from wc -l output
                e_count=$(echo "$JOB_SPECIFIER" | grep -o -i 'e' | wc -l | tr -d ' ')
                if [[ "$e_count" -gt 0 ]]; then
                    NEW_PARALLEL_JOBS_VALUE="$e_count"
                    # This will be applied after loop to override PARALLEL_JOBS
                    # and set USE_PARALLEL_PROCESSING="true"
                else
                    echo "Warning: Job specifier '${JOB_SPECIFIER}' for $1 option resulted in 0 'e's. Ignoring this job count setting." >&2
                fi
                shift # past argument
                shift # past value
            else
                echo "Error: Missing argument for $1 option." >&2
                usage
            fi
            ;;
        -h|--help)
            usage
            ;;
        -*) # Unknown option
            echo "Unknown option: $1" >&2
            usage
            ;;
        *)  # Positional argument (should be input directory)
            if [[ -z "$NEW_INPUT_DIR_VALUE" ]]; then
                NEW_INPUT_DIR_VALUE="$1"
            else
                echo "Error: Too many input directories specified. Already have '${NEW_INPUT_DIR_VALUE}', got '$1'." >&2
                usage
            fi
            shift # past argument
            ;;
    esac
done

# Apply parsed arguments, overriding defaults from Configuration section
if [[ -n "$NEW_PARALLEL_JOBS_VALUE" ]]; then
    PARALLEL_JOBS="$NEW_PARALLEL_JOBS_VALUE"
    USE_PARALLEL_PROCESSING="true" # Enable parallel if jobs are specified this way via command line
    echo "Command-line: Parallel jobs set to ${PARALLEL_JOBS}. Parallel processing enabled."
fi

if [[ -n "$NEW_INPUT_DIR_VALUE" ]]; then
    INPUT_DIR="$NEW_INPUT_DIR_VALUE"
    # echo "Command-line: Input directory set to ${INPUT_DIR}." # Will be printed later by main script logic
fi
# --- End Argument Parsing ---


# Function to check for required external command-line tools
check_dependencies() {
  local missing_deps=0
  # Critical external commands needed for the script to function
  local critical_deps=("convert" "tesseract" "img2pdf" "realpath" "sort" "find" "basename")

  if [[ "${USE_UNPAPER}" == "true" ]]; then
    critical_deps+=("unpaper")
  fi
  if [[ "${USE_PARALLEL_PROCESSING}" == "true" ]]; then
    critical_deps+=("parallel")
  fi

  echo "--- Checking for required tools ---"
  for cmd in "${critical_deps[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
      echo "Error: Required command '$cmd' is not installed or not in PATH."
      missing_deps=1
    fi
  done

  if [[ "${AUTO_ROTATE_VIA_OSD}" == "true" ]]; then
    # Check if Tesseract has OSD data installed by trying to list OSD language
    if ! tesseract --list-langs 2>&1 | grep -qE '\bosd\b'; then
        echo "Error: Tesseract OSD data (osd.traineddata) not found. Needed for AUTO_ROTATE_VIA_OSD."
        echo "       Please install the Tesseract OSD language pack (e.g., tesseract-ocr-osd or tesseract-data-osd)."
        missing_deps=1
    fi
  fi

  if [[ $missing_deps -eq 1 ]]; then
    echo "Please install the missing dependencies and try again."
    echo "Common packages:"
    echo "  - ImageMagick (provides 'convert')"
    echo "  - Tesseract OCR (provides 'tesseract' and language packs like 'tesseract-ocr-eng')"
    echo "  - img2pdf (provides 'img2pdf')"
    echo "  - coreutils (usually provides 'realpath', 'sort', 'basename', 'find' on Linux)"
    if [[ "${USE_UNPAPER}" == "true" ]]; then
      echo "  - unpaper (provides 'unpaper')"
    fi
    if [[ "${AUTO_ROTATE_VIA_OSD}" == "true" ]]; then
      echo "  - tesseract-ocr-osd (or similar, for 'osd.traineddata')"
    fi
    if [[ "${USE_PARALLEL_PROCESSING}" == "true" ]]; then
      echo "  - parallel (GNU Parallel)"
    fi
    echo "For GPU acceleration (if USE_GPU is true):"
    echo "  - Tesseract OCR must be version 5+ and compiled with OpenCL support."
    echo "  - ImageMagick must be compiled with OpenCL support."
    echo "  - Your system needs appropriate GPU drivers and OpenCL runtimes."
    exit 1
  fi
  echo "All critical dependencies found."
  # Informational notes
  [[ "${USE_GPU}" == "true" ]] && echo "Note: USE_GPU is true. Actual GPU usage depends on Tesseract/ImageMagick builds and system OpenCL setup."
  [[ "${USE_UNPAPER}" == "true" ]] && echo "Note: USE_UNPAPER is true. Using 'unpaper' for advanced pre-processing."
  [[ "${AUTO_ROTATE_VIA_OSD}" == "true" ]] && echo "Note: AUTO_ROTATE_VIA_OSD is true. Using Tesseract OSD for auto-rotation."
  [[ "${USE_PARALLEL_PROCESSING}" == "true" ]] && echo "Note: USE_PARALLEL_PROCESSING is true. Using GNU Parallel with ${PARALLEL_JOBS} job(s) (0 means one per core)."
  echo "------------------------------------"
}


# Function to process a single image file
# This function will be called by GNU Parallel for each image.
# It needs all relevant configuration variables to be exported.
process_single_image() {
    local img_file_path="$1" # Argument passed by parallel
    # All configuration variables are expected to be available via export

    local img_filename
    img_filename=$(basename "${img_file_path}")
    local base_name
    base_name=$(basename "${img_filename}" ."${img_filename##*.}")

    # Define output paths based on the image's base name
    local processed_img_output="${PROCESSED_IMG_DIR}/${base_name}_processed.png"
    local individual_pdf_output_prefix="${INDIVIDUAL_PDF_DIR}/${base_name}"

    echo "Processing: ${img_filename}" # This output might be interleaved in parallel mode

    local current_image_to_process="${img_file_path}"
    local unpaper_was_successful=false
    local osd_rotation_applied=false

    # Stage 1a: Optional unpaper processing
    if [[ "${USE_UNPAPER}" == "true" ]]; then
        echo "  1a. (${img_filename}) Advanced pre-processing with unpaper..."
        local unpaper_pre_converted_input="${PROCESSED_IMG_DIR}/${base_name}_pre_unpaper.png"
        local unpaper_output_image="${PROCESSED_IMG_DIR}/${base_name}_unpapered.png"

        if ! convert "${current_image_to_process}" -auto-orient -colorspace sRGB "${unpaper_pre_converted_input}"; then
            echo "       WARNING: (${img_filename}) Pre-conversion for unpaper failed. Skipping unpaper."
            rm -f "${unpaper_pre_converted_input}" 2>/dev/null
        else
            local unpaper_opts_array=() 
            read -r -a unpaper_opts_array <<< "$UNPAPER_OPTIONS"
            if ! unpaper "${unpaper_opts_array[@]}" "${unpaper_pre_converted_input}" "${unpaper_output_image}"; then
                echo "       WARNING: (${img_filename}) unpaper failed for '${unpaper_pre_converted_input}'. Proceeding without unpaper's output."
            else
                echo "       Done (unpaper for ${img_filename}): ${unpaper_output_image}"
                current_image_to_process="${unpaper_output_image}"
                unpaper_was_successful=true
            fi
            rm -f "${unpaper_pre_converted_input}" 
        fi
    fi

    # Stage 1b: Optional OSD-based rotation
    if [[ "${AUTO_ROTATE_VIA_OSD}" == "true" ]]; then
        echo "  1b. (${img_filename}) OSD-based rotation check..."
        local osd_rotated_image_path="${PROCESSED_IMG_DIR}/${base_name}_osd_rotated.png"
        
        local osd_output_stderr_combined
        osd_output_stderr_combined=$(tesseract "${current_image_to_process}" stdout --psm 0 -l osd 2>&1)
        
        local rotation_angle=""
        if grep -q "Error" <<< "${osd_output_stderr_combined}" || [[ ${#osd_output_stderr_combined} -lt 10 ]]; then
            echo "       WARNING: (${img_filename}) Tesseract OSD process failed or produced minimal output. Output: ${osd_output_stderr_combined}"
        else
            rotation_angle=$(echo "${osd_output_stderr_combined}" | grep 'Rotate:' | awk '{print $2}')
        fi

        if [[ -n "$rotation_angle" && "$rotation_angle" != "0" && ( "$rotation_angle" == "90" || "$rotation_angle" == "180" || "$rotation_angle" == "270" ) ]]; then
            echo "       (${img_filename}) OSD detected rotation: ${rotation_angle} degrees. Applying correction."
            if ! convert "${current_image_to_process}" -rotate "${rotation_angle}" "${osd_rotated_image_path}"; then
                echo "       WARNING: (${img_filename}) OSD-based rotation with 'convert -rotate' failed. Using previous image."
            else
                echo "       Done (OSD rotation for ${img_filename}): ${osd_rotated_image_path}"
                current_image_to_process="${osd_rotated_image_path}"
                osd_rotation_applied=true
            fi
        elif [[ -n "$rotation_angle" && "$rotation_angle" == "0" ]]; then
            echo "       (${img_filename}) OSD detected orientation as correct (0 degrees rotation needed)."
        else
            echo "       (${img_filename}) OSD: No significant rotation detected or OSD failed. Angle: [${rotation_angle}]."
        fi
    fi

    # Stage 1c: Main ImageMagick processing
    echo "  1c. (${img_filename}) Final ImageMagick pre-processing..."
    local convert_options=() 
    if [[ "$osd_rotation_applied" == "false" ]]; then
        convert_options+=("-auto-orient")
    else
        echo "       (${img_filename}) (Skipping -auto-orient as OSD rotation was applied)"
    fi

    if ! $unpaper_was_successful ; then
        convert_options+=("-deskew" "${DESKEW_PERCENT}")
    else
        echo "       (${img_filename}) (Skipping ImageMagick -deskew as unpaper was used successfully)"
    fi
    convert_options+=("-normalize" "-colorspace" "Gray" "-fuzz" "${TRIM_FUZZ}" "-trim" "+repage")

    if ! convert "${current_image_to_process}" "${convert_options[@]}" "${processed_img_output}"; then
        echo "     ERROR: (${img_filename}) ImageMagick 'convert' failed for input '${current_image_to_process}'. Skipping."
        return 1 
    fi
    echo "     Done (ImageMagick final pre-processing for ${img_filename}): ${processed_img_output}"

    # Stage 2: OCR
    echo "  2. (${img_filename}) OCRing to individual PDF..."
    local tesseract_cmd_prefix=""
    if [[ "${USE_GPU}" == "true" ]]; then
        tesseract_cmd_prefix="OMP_THREAD_LIMIT=1 "
        echo "     (${img_filename}) (Hinting Tesseract to use GPU via OMP_THREAD_LIMIT=1)"
    fi

    local tesseract_full_command=() 
    if [[ -n "$tesseract_cmd_prefix" ]]; then
        tesseract_full_command+=("env" "OMP_THREAD_LIMIT=1")
    fi
    tesseract_full_command+=("tesseract" "${processed_img_output}" "${individual_pdf_output_prefix}" "-l" "${OCR_LANG}" "pdf")

    if ! "${tesseract_full_command[@]}"; then
        echo "     ERROR: (${img_filename}) Tesseract OCR failed for '${processed_img_output}'. Skipping PDF creation."
        rm -f "${individual_pdf_output_prefix}.pdf" 2>/dev/null
        return 1 
    fi
    echo "     Done (Tesseract for ${img_filename}): ${individual_pdf_output_prefix}.pdf"
    return 0 
}
# Export the function and necessary variables so GNU Parallel can use them
export -f process_single_image
export PROCESSED_IMG_DIR INDIVIDUAL_PDF_DIR OCR_LANG USE_GPU USE_UNPAPER UNPAPER_OPTIONS AUTO_ROTATE_VIA_OSD DESKEW_PERCENT TRIM_FUZZ


# --- Initialize ---
check_dependencies # Call after argument parsing, as flags might change dependency needs
set -e 
mkdir -p "${PROCESSED_IMG_DIR}" "${INDIVIDUAL_PDF_DIR}" 

# --- Main Script ---
echo ""
echo "--- Starting Document Processing ---"
abs_input_dir=$(realpath "${INPUT_DIR}")
abs_output_dir_base=$(realpath "${OUTPUT_DIR_BASE}")

echo "Input Directory: ${abs_input_dir}"
echo "OCR Language: ${OCR_LANG}"
echo "Attempting GPU use (Tesseract): ${USE_GPU}"
echo "Using unpaper: ${USE_UNPAPER}"
echo "Using OSD auto-rotation: ${AUTO_ROTATE_VIA_OSD}"
echo "Using Parallel Processing: ${USE_PARALLEL_PROCESSING}"
if [[ "${USE_PARALLEL_PROCESSING}" == "true" ]]; then
    echo "Number of Parallel Jobs: ${PARALLEL_JOBS} (0 means one job per core)"
fi
echo "Output will be in: ${abs_output_dir_base}"
echo "------------------------------------"
echo ""

mapfile -d $'\0' images < <(find "${INPUT_DIR}" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) -print0 | sort -zV)

if [[ ${#images[@]} -eq 0 ]]; then
  echo "No JPG or JPEG images found in '${abs_input_dir}'."
  echo "Cleaning up directories created by this script run..."
  rmdir "${PROCESSED_IMG_DIR}" 2>/dev/null || true
  rmdir "${INDIVIDUAL_PDF_DIR}" 2>/dev/null || true
  if [ -d "${OUTPUT_DIR_BASE}" ] && [ -z "$(ls -A "${OUTPUT_DIR_BASE}")" ]; then
    echo "Removing empty base output directory: '${abs_output_dir_base}'"
    rmdir "${OUTPUT_DIR_BASE}" 2>/dev/null || true
  else
    echo "Base output directory '${abs_output_dir_base}' not removed as it may contain other files."
  fi
  exit 0
fi

echo "Found ${#images[@]} image(s) to process."
echo ""

# Process images: either sequentially or in parallel
if [[ "${USE_PARALLEL_PROCESSING}" == "true" ]]; then
    echo "--- Processing images in parallel ---"
    # Ensure PARALLEL_JOBS is set; if it became empty for some reason, default to 0
    current_parallel_jobs=${PARALLEL_JOBS:-0}

    if ! find "${INPUT_DIR}" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) -print0 | \
        parallel --no-notice -0 -j "${current_parallel_jobs}" process_single_image {}; then
        echo "WARNING: One or more parallel image processing jobs failed. See output above."
    fi
    echo "--- Parallel image processing finished ---"
else
    echo "--- Processing images sequentially ---"
    job_count=0
    failed_jobs=0
    for ((i=0; i<${#images[@]}; i++)); do
        echo "Sequential job (${i+1}/${#images[@]}):"
        if ! process_single_image "${images[i]}"; then
            failed_jobs=$((failed_jobs + 1))
        fi
        job_count=$((job_count + 1))
    done
    echo "--- Sequential image processing finished. Processed ${job_count} images. Failed: ${failed_jobs} ---"
fi


# Stage 3: Combine PDFs (always sequential, after all image processing)
echo ""
echo "--- Combining PDFs ---"
mapfile -d $'\0' pdfs_to_combine < <(find "${INDIVIDUAL_PDF_DIR}" -maxdepth 1 -iname "*.pdf" -type f -print0 | sort -zV)

if [[ ${#pdfs_to_combine[@]} -gt 0 ]]; then
  echo "Found ${#pdfs_to_combine[@]} individual PDF(s) to combine."
  final_combined_pdf_path="${OUTPUT_DIR_BASE}/${COMBINED_PDF_NAME}"

  if img2pdf "${pdfs_to_combine[@]}" -o "${final_combined_pdf_path}"; then
    echo "Successfully created combined PDF: ${final_combined_pdf_path}"
  else
    echo "ERROR: img2pdf failed to combine PDFs. Individual PDFs are in '${INDIVIDUAL_PDF_DIR}'."
    exit 1
  fi
else
  echo "No individual PDF files were successfully created to combine. Check for errors."
fi

# Stage 4: Cleanup
if [[ "${CLEANUP_INTERMEDIATE}" == "true" ]]; then
  echo ""
  echo "--- Cleaning up intermediate files ---"
  if [ -d "${PROCESSED_IMG_DIR}" ]; then
    rm -rf "${PROCESSED_IMG_DIR}"
    echo "Removed intermediate images directory: ${PROCESSED_IMG_DIR}"
  fi
  if [ -s "${final_combined_pdf_path}" ] && [ -d "${INDIVIDUAL_PDF_DIR}" ]; then
     rm -rf "${INDIVIDUAL_PDF_DIR}"
     echo "Removed individual PDFs directory: ${INDIVIDUAL_PDF_DIR}"
  elif [ -d "${INDIVIDUAL_PDF_DIR}" ]; then
     echo "Individual PDFs directory not removed (combined PDF might have failed or other reasons)."
  fi
  echo "Cleanup complete."
fi

echo ""
echo "--- Processing Complete ---"
if [ -f "${final_combined_pdf_path}" ]; then
    echo "Final output: $(realpath "${final_combined_pdf_path}")"
else
    echo "Processing finished, but the final combined PDF was not created. Please check logs."
fi
echo "------------------------------------"

exit 0
