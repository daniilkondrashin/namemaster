FROM python:3.10.12-slim
COPY app/requirements.txt /app/requirements.txt
WORKDIR /app
RUN pip install --no-cache-dir -r requirements.txt 
COPY app /app
EXPOSE 5000
CMD ["python3", "main.py"]
