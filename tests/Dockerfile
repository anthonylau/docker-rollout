FROM nginx:alpine

ARG VERSION=v1
ENV APP_VERSION=${VERSION}

# Create a simple HTML page that shows the version
RUN echo "<html><body><h1>App Version: ${APP_VERSION}</h1></body></html>" > /usr/share/nginx/html/index.html

# Add healthcheck
HEALTHCHECK --interval=2s --timeout=1s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:80/ || exit 1

EXPOSE 80
