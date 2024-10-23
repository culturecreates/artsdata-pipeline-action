FROM ruby:3.1.2

RUN apt-get update && apt-get install -y \
    curl \
    apt-transport-https \
    ca-certificates \
    libx11-xcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxi6 \
    libxtst6 \
    libnss3 \
    libxrandr2 \
    libasound2 \
    libpangocairo-1.0-0 \
    libatk1.0-0 \
    libcups2 \
    libgbm1 \
    libpangoft2-1.0-0 \
    libjpeg-dev \
    libxshmfence1 \
    libgles2-mesa \
    xvfb \
    --no-install-recommends && \
    curl -sSL https://dl.google.com/linux/linux_signing_key.pub | apt-key add - && \
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && apt-get install -y google-chrome-stable --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY . .

ENTRYPOINT ["bundle", "exec", "ruby", "src/main.rb"]
