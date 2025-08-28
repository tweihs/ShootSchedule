import os

import pandas as pd


def read_and_merge_datasets(file_paths, labels):
    # List to hold dataframes
    data_frames = []

    # Loop through file paths and labels
    for file_path, label in zip(file_paths, labels):
        # Read the XLS file
        df = pd.read_excel(file_path)

        # if "NSCA" in file_path and "2019" in file_path:
        #     # Check if "Region" is in the headers and shift headers if necessary
        #     headers = df.columns.tolist()
        #     if "Region" in headers:
        #         headers.remove("Region")
        #         # df.columns = headers + ['Extra'][:len(headers)]

        # Add a new column 'type' to indicate the source file
        df['Event Type'] = label
        # Append to the list of dataframes
        data_frames.append(df)

    # Concatenate all dataframes into one
    combined_df = pd.concat(data_frames, ignore_index=True)

    return combined_df


def clean_event_names(df):
    # Remove multiple newlines from event names
    df['Shoot Name'] = df['Shoot Name'].str.replace('\n', '')
    df['Shoot Name'] = df['Shoot Name'].str.strip('"')
    df['POC Phone'] = df['POC Phone'].str.replace("'", "")
    # df['Shoot Name'] = re.sub(r'(\b\w+\b)\s+\1', r'\1', df['Shoot Name'])
    return df


def merge(output_dir, urls):
    # Extract filenames from the URLs
    filenames = [url.split('/')[-1] for url in urls]

    # List of file paths and corresponding labels
    file_paths = [os.path.join(output_dir, filename) for filename in filenames]

    labels = ["NSSA", "NSCA"]

    # Get the combined dataset
    combined_dataset = read_and_merge_datasets(file_paths, labels)

    # Clean Event Names
    combined_dataset = clean_event_names(combined_dataset)

    # Display the combined dataset
    print(combined_dataset)

    def save_to_csv(dataframe, output_filename):
        # Write the DataFrame to a CSV file
        dataframe.to_csv(output_filename, index=False)
        print(f"Data saved to '{output_filename}' successfully.")

    # Specify the output filename
    output_filename = os.path.join(output_dir, "Combined_Shoot_Schedule_2024.csv")

    # Save the combined dataset to a CSV file
    save_to_csv(combined_dataset, output_filename)


if __name__ == "__main__":
    # Determine if running inside a Docker container
    if os.path.exists('/.dockerenv') or os.getenv('IN_DOCKER'):
        # Docker workdir is /usr/src/app, files are relative to that
        output_dir = "data"
    else:
        output_dir = "../data"

    merge(output_dir)