import os
import requests
import json
from datetime import datetime
import xlrd, xlwt
# import openpyxl



def download_files(urls, output_dir):
    # Load last modified times from JSON file
    last_modified_file = os.path.join(output_dir, "last_modified.json")
    last_modified_data = {}
    print("looking for last modified cachefile at " + last_modified_file)
    if os.path.exists(last_modified_file):
        try:
            with open(last_modified_file, "r") as f:
                last_modified_data = json.load(f)
                print("last modified cachefile loaded")
        except json.decoder.JSONDecodeError:
            print("Error: Unable to load last modified data. Creating new file.")
            last_modified_data = {}
    else:
        print("last nodified cachefile not detected")

    # Array to store whether each URL was downloaded
    downloaded = []

    for url in urls:
        # Get filename from URL
        filename = os.path.join(output_dir, url.split('/')[-1])

        # Get last modified time from URL headers
        response = requests.head(url)
        last_modified_url = response.headers.get('last-modified')

        # Convert last modified time to datetime object
        last_modified_url_datetime = datetime.strptime(last_modified_url, '%a, %d %b %Y %H:%M:%S %Z') if last_modified_url else None

        # Check if file needs to be downloaded
        download_required = True
        if last_modified_url_datetime:
            last_modified_data_saved = last_modified_data.get(url)
            if last_modified_data_saved:
                last_modified_data_saved_datetime = datetime.strptime(last_modified_data_saved, '%a, %d %b %Y %H:%M:%S %Z')
                if last_modified_data_saved_datetime == last_modified_url_datetime:
                    download_required = False

        if not os.path.exists(filename):
            download_required = True

        # Download file if required
        if download_required:
            response = requests.get(url)
            with open(filename, 'wb') as f:
                f.write(response.content)
            downloaded.append(True)
            print(f"Downloaded: {filename}")
        else:
            downloaded.append(False)
            print(f"Skipped: {filename} (last modified date not changed)")

        # Update last modified data
        last_modified_data[url] = last_modified_url if last_modified_url else None

    # Save last modified times to JSON file
    with open(last_modified_file, "w") as f:
        json.dump(last_modified_data, f)

    if any(downloaded):
        file = os.path.join(output_dir, urls[1].split('/')[-1])
        fix_nsca_column_names(file)

    return downloaded

import xlrd
import xlwt
import os

def fix_nsca_column_names(file):
    # Path to your existing Excel file
    input_file_path = file
    # Path for saving the modified Excel file
    directory, filename = os.path.split(file)
    name_part, extension = os.path.splitext(filename)
    output_file_path = os.path.join(directory, f"{name_part}_modified{extension}")

    print(f"Input file path: {input_file_path}")
    print(f"Output file path: {output_file_path}")

    # Open the workbook for reading
    try:
        rb = xlrd.open_workbook(input_file_path)
        sheet = rb.sheet_by_index(0)  # Assuming the data is in the first sheet
    except Exception as e:
        print(f"Error opening file {input_file_path}: {e}")
        return

    # Create a new workbook for writing
    wb = xlwt.Workbook()
    ws = wb.add_sheet('Sheet1')  # Create a new sheet

    # Read headers and determine where to insert the new column "Zone"
    headers = sheet.row_values(0)
    insert_index = headers.index("Club E-Mail")
    modified_headers = headers[:insert_index] + ['Zone'] + headers[insert_index:]

    for col_num, header in enumerate(modified_headers):
        ws.write(0, col_num, header)

    for row_index in range(1, sheet.nrows):
        for col_index in range(sheet.ncols):
            value = sheet.cell_value(row_index, col_index)
            ws.write(row_index, col_index, value)

    # Save the modified workbook
    try:
        wb.save(output_file_path)
        print(f"Modified file saved as: {output_file_path}")

        # Replace original file with modified file
        os.replace(output_file_path, input_file_path)
        print(f"Replaced original file with modified file: {input_file_path}")
    except Exception as e:
        print(f"Error saving file {output_file_path}: {e}")

def main():
    # Example usage:
    # urls = [
    #     "https://www.nssa-nsca.org/Schedules/NSSA_2024_Shoot_Schedule_For_Web.xls",
    #     "https://www.nssa-nsca.org/Schedules/NSCA_2024_Shoot_Schedule_For_Web.xls"
    # ]

    base_urls = [
        "https://www.nssa-nsca.org/Schedules/NSSA_{}_Shoot_Schedule_For_Web.xls",
        "https://www.nssa-nsca.org/Schedules/NSCA_{}_Shoot_Schedule_For_Web.xls"
    ]

    years = range(2024, 2025)
    urls = []

    for base_url in base_urls:
        for year in years:
            urls.append(base_url.format(year))

    output_dir = "../data"
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    downloaded = download_files(urls, output_dir)

    # fix the issue in the NSSA file with column order
    file = os.path.join(output_dir, urls[1].split('/')[-1])
    fix_nsca_column_names(file)

    print(downloaded)


if __name__ == "__main__":
    main()
