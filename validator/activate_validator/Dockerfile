# Use an Alpine image with Python 3
FROM python:3-alpine

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy the requirements file into the container
COPY requirements.txt ./

# Install dependencies from the requirements file
RUN pip install --no-cache-dir -r requirements.txt

# Copy the Python script into the container
COPY activate_validator.py .

# Command to run when the container starts
CMD ["python", "./activate_validator.py"]
