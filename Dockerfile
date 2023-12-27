FROM python:3.10.12-slim
COPY app /app
WORKDIR /app
RUN pip3 install -r requirements.txt 
EXPOSE 5000
ENTRYPOINT ["python3"]
CMD ["main.py"]