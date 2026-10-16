FROM nginx:1.27-alpine

# Place template in Nginx auto-substitution directory
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY index.html /usr/share/nginx/html/index.html

# Defaults if not supplied
#ENV BACKEND_HOST=demo-be
#ENV BACKEND_PORT=4000

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
