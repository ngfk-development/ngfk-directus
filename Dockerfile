FROM directus/directus:11.6

USER root
RUN corepack enable

USER node
RUN pnpm install directus-extension-flexible-editor

CMD ["/bin/sh", "-c", ": \t&& node cli.js bootstrap \t&& pm2-runtime start ecosystem.config.cjs \t;"]
