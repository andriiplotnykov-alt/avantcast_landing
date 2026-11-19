
FROM nginx:alpine

COPY avantcast-landing.html /usr/share/nginx/html/index.html

COPY fr.js /usr/share/nginx/html/fr.js

EXPOSE 80
