# ============================
# Stage 1: Build React frontend
# ============================
FROM node:18 AS build-frontend
WORKDIR /app/frontend

COPY project/frontend/package*.json ./
RUN npm install

COPY project/frontend/ ./
RUN npm run build

# ============================
# Stage 2: Setup Rails backend
# ============================
FROM ruby:3.2 AS build-backend
WORKDIR /app/backend

# Install required packages, yarn, MySQL client dev
RUN apt-get update -qq && apt-get install -y \
    nodejs \
    curl \
    gnupg2 \
    default-libmysqlclient-dev \
    build-essential \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update && apt-get install -y yarn \
    && rm -rf /var/lib/apt/lists/*

COPY project/backend/Gemfile* ./
RUN gem install bundler && bundle lock --add-platform x86_64-linux && bundle install

COPY project/backend/ ./

# ============================
# Stage 3: Apache frontend + backend proxy
# ============================
FROM httpd:2.4 AS apache
WORKDIR /usr/local/apache2

RUN apt-get update && apt-get install -y apache2-utils curl && rm -rf /var/lib/apt/lists/*

# Enable Apache proxy modules
RUN echo "LoadModule proxy_module modules/mod_proxy.so" >> conf/httpd.conf \
    && echo "LoadModule proxy_http_module modules/mod_proxy_http.so" >> conf/httpd.conf

# Copy React build into Apache docroot
COPY --from=build-frontend /app/frontend/build/ htdocs/

# Configure Apache virtual host with backend proxy
RUN echo '<VirtualHost *:80>\n' \
         'DocumentRoot "/usr/local/apache2/htdocs"\n' \
         '<Directory "/usr/local/apache2/htdocs">\n' \
         'Options -Indexes +FollowSymLinks\n' \
         'AllowOverride All\n' \
         'Require all granted\n' \
         '</Directory>\n' \
         'ProxyPass "/api" "http://backend:3000"\n' \
         'ProxyPassReverse "/api" "http://backend:3000"\n' \
         '</VirtualHost>\n' \
         > conf/extra/httpd-vhosts.conf

RUN echo "Include conf/extra/httpd-vhosts.conf" >> conf/httpd.conf

EXPOSE 80
CMD ["httpd-foreground"]

