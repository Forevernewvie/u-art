FROM python:3.10-alpine
WORKDIR /usr/src/app
COPY requirements.txt ./
# Install build dependencies for some python packages if needed (like lxml, but we can use html.parser)
# RUN apk add --no-cache gcc musl-dev
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD [ "python", "-u", "main.py" ]
