FROM python:3.10.12-slim
COPY app /app
WORKDIR /app
RUN pip3 install --no-cache-dir -r requirements.txt 
COPY . .
ENV FLASK_APP=app
ENV FLASK_RUN_HOST=0.0.0.0
EXPOSE 5000
ENTRYPOINT ["python3"]
CMD ["main.py"]