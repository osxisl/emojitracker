require_relative 'lib/config'
require_relative 'lib/emoji'

require 'sinatra'
require 'slim'
require 'coffee-script'

set :public_folder, 'public'

get '/' do
  slim :index
end

get '/application.js' do
  coffee :application
end

get '/data' do
  raw_scores = REDIS.zrange('emojitrack_score', 0, -1, { withscores: true } ).reverse
  @scores = raw_scores.map do |score|
    emo_obj = Emoji.find_by_codepoint(score[0])
    # yield "FUCK" if emo_obj.nil?
    {
      "char" => Emoji.codepoint_to_char(score[0]),
      "id" => emo_obj.unified,
      "name" => emo_obj.nil? ? '***FUCK***' : emo_obj.name,
      "score" => score[1].to_i
    }
  end

  content_type :json
  Oj.dump( @scores )
end

conns = []
get '/subscribe' do
  content_type 'text/event-stream'
  stream(:keep_open) do |out|
    conns << out
    out.callback { conns.delete(out) }
  end
end

Thread.new do
  # we need a new instance of the redis object for this
  t_redis = Redis.new(:host => REDIS_URI.host, :port => REDIS_URI.port, :password => REDIS_URI.password)

  t_redis.psubscribe('stream.score_updates') do |on|
    on.pmessage do |match, channel, message|
      # type = channel.sub('stream.tweets.', '')
      conns.each do |out|
        out << "event: #{channel}\n"
        out << "data: #{message}\n\n"
      end
    end
  end

end
