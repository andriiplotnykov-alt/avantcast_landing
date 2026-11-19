
FROM nginx:alpine

COPY index.html /usr/share/nginx/html/index.html
COPY fr.js /usr/share/nginx/html/fr.js

EXPOSE 80
