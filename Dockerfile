FROM ruby:3.1.2

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY . .

ENTRYPOINT ["bundle", "exec", "ruby", "src/main.rb"]
