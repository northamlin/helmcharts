from ubuntu
RUN apt-get update && apt-get install -y mysql-client netcat curl
ADD db /db
ADD insert.sh /insert.sh
RUN chmod +x /insert.sh
CMD /insert.sh
