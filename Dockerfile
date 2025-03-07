FROM nginx:stable-alpine

COPY --chown=nginx:nginx entrypoint.sh /entrypoint.sh
COPY index.html /usr/share/nginx/html/

# Modify permissions to run as nginx user
RUN chown -R nginx:nginx /var/cache/nginx \
    && chown -R nginx:nginx /usr/share/nginx/html \
    && chown -R nginx:nginx /var/log/nginx \
    && chown -R nginx:nginx /etc/nginx/conf.d \
    && touch /var/run/nginx.pid \
    && chown -R nginx:nginx /var/run/nginx.pid

# uid=101(nginx)
USER 101

ENTRYPOINT ["/entrypoint.sh"]

CMD ["nginx", "-g", "daemon off;"]
