#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'uri'

COINS = {
  'bitcoin' => { symbol: '₿', short: 'BTC' },
  'ethereum' => { symbol: '', short: 'ETH' },
  'monero' => { symbol: '', short: 'XMR' },
  'solana' => { symbol: '◎', short: 'SOL' }
}

CURRENCY = 'usd'
CACHE_FILE = "/tmp/waybar_crypto_cache.json"
CACHE_DURATION = 60

# Catppuccin Mocha colors
COLORS = {
  rosewater: '#f5e0dc',
  flamingo:  '#f2cdcd',
  pink:      '#f5c2e7',
  mauve:     '#cba6f7',
  red:       '#f38ba8',
  maroon:    '#eba0ac',
  peach:     '#fab387',
  yellow:    '#f9e2af',
  green:     '#a6e3a1',
  teal:      '#94e2d5',
  sky:       '#89dceb',
  sapphire:  '#74c7ec',
  blue:      '#89b4fa',
  lavender:  '#b4befe',
  text:      '#cdd6f4',
  subtext1:  '#bac2de',
  subtext0:  '#a6adc8',
  overlay2:  '#9399b2',
  overlay1:  '#7f849c',
  overlay0:  '#6c7086',
  surface2:  '#585b70',
  surface1:  '#45475a',
  surface0:  '#313244',
  base:      '#1e1e2e',
  mantle:    '#181825',
  crust:     '#11111b'
}

class CryptoFetcher
  def initialize
    @cache = load_cache
  end

  def fetch_data
    return @cache if cache_valid?

    begin
      ids = COINS.keys.join(',')
      uri = URI("https://api.coingecko.com/api/v3/coins/markets")
      params = {
        vs_currency: CURRENCY,
        ids: ids,
        order: 'market_cap_desc',
        per_page: 4,
        page: 1,
        sparkline: true,
        price_change_percentage: '1h,24h,7d,30d'
      }
      uri.query = URI.encode_www_form(params)

      response = Net::HTTP.get_response(uri)

      if response.code == '200'
        data = JSON.parse(response.body)
        save_cache(data)
        @cache = data
      else
        @cache
      end
    rescue => e
      STDERR.puts "Error fetching crypto data: #{e.message}"
      @cache
    end
  end

  private

  def cache_valid?
    return false unless @cache && @cache['timestamp']
    Time.now.to_i - @cache['timestamp'] < CACHE_DURATION
  end

  def load_cache
    return nil unless File.exist?(CACHE_FILE)
    JSON.parse(File.read(CACHE_FILE))
  rescue
    nil
  end

  def save_cache(data)
    cache = {
      'timestamp' => Time.now.to_i,
      'data' => data
    }
    File.write(CACHE_FILE, JSON.generate(cache))
    cache
  end
end

class CryptoFormatter
  def initialize(data)
    @data = data.is_a?(Hash) && data['data'] ? data['data'] : data
  end

  def waybar_text
    return '' unless @data && @data.is_a?(Array)

    prices = @data.map do |coin|
      info = COINS[coin['id']]
      price = format_price(coin['current_price'])
      change = coin['price_change_percentage_24h']

      icon = info[:symbol]
      "#{icon} #{price}"
    end

    prices.join('  ')
  end

  def waybar_tooltip
    return colorize('Loading crypto data...', COLORS[:overlay0]) unless @data && @data.is_a?(Array)

    lines = [colorize("crypto market data", COLORS[:blue], bold: true), ""]

    @data.each do |coin|
      info = COINS[coin['id']]
      lines << format_coin_details(coin, info)
      lines << ""
    end

    lines << format_market_summary

    lines.join("\n")
  end

  def waybar_json
    {
      text: waybar_text,
      tooltip: waybar_tooltip,
      class: 'crypto'
    }
  end

  private

  def format_coin_details(coin, info)
    name = coin['name']
    symbol = info[:short]
    price = format_price(coin['current_price'])

    change_1h = coin.dig('price_change_percentage_1h_in_currency') || 0
    change_24h = coin['price_change_percentage_24h'] || 0
    change_7d = coin.dig('price_change_percentage_7d_in_currency') || 0
    change_30d = coin.dig('price_change_percentage_30d_in_currency') || 0

    high_24h = format_price(coin['high_24h'])
    low_24h = format_price(coin['low_24h'])

    market_cap = format_large_number(coin['market_cap'])
    volume_24h = format_large_number(coin['total_volume'])

    trend = get_trend(coin['sparkline_in_7d']['price']) if coin['sparkline_in_7d']

    # Choose coin color
    coin_color = case coin['id']
    when 'bitcoin' then COLORS[:peach]
    when 'ethereum' then COLORS[:lavender]
    when 'monero' then COLORS[:maroon]
    when 'solana' then COLORS[:green]
    else COLORS[:text]
    end

    [
      colorize("#{name} (#{symbol})", coin_color, bold: true),
      "  #{colorize('price', COLORS[:subtext0])}       #{colorize("$#{price}", COLORS[:text])}",
      "  #{colorize('24h range', COLORS[:subtext0])}   #{colorize("$#{low_24h}", COLORS[:red])} / #{colorize("$#{high_24h}", COLORS[:green])}",
      "",
      "  #{colorize('change:', COLORS[:subtext1])}",
      "    #{colorize('1h', COLORS[:overlay1])}        #{format_change_colored(change_1h)}",
      "    #{colorize('24h', COLORS[:overlay1])}       #{format_change_colored(change_24h)}",
      "    #{colorize('7d', COLORS[:overlay1])}        #{format_change_colored(change_7d)}",
      "    #{colorize('30d', COLORS[:overlay1])}       #{format_change_colored(change_30d)}",
      "",
      "  #{colorize('market cap', COLORS[:subtext0])}  #{colorize("$#{market_cap}", COLORS[:blue])}",
      "  #{colorize('24h volume', COLORS[:subtext0])}  #{colorize("$#{volume_24h}", COLORS[:sapphire])}",
      trend ? "  #{colorize('trend', COLORS[:subtext0])}       #{format_trend_colored(trend)}" : nil
    ].compact.join("\n")
  end

  def format_market_summary
    total_market_cap = @data.sum { |c| c['market_cap'] }
    total_volume = @data.sum { |c| c['total_volume'] }
    avg_change = @data.sum { |c| c['price_change_percentage_24h'] || 0 } / @data.length

    [
      colorize("market summary", COLORS[:mauve], bold: true),
      "  #{colorize('total market cap', COLORS[:subtext0])}  #{colorize("$#{format_large_number(total_market_cap)}", COLORS[:blue])}",
      "  #{colorize('total volume', COLORS[:subtext0])}      #{colorize("$#{format_large_number(total_volume)}", COLORS[:sapphire])}",
      "  #{colorize('avg 24h change', COLORS[:subtext0])}    #{format_change_colored(avg_change)}"
    ].join("\n")

  end

  def format_price(price)
    return '0.00' unless price

    if price >= 1000
      price.round(2).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    elsif price >= 1
      format('%.2f', price)
    else
      format('%.4f', price)
    end
  end

  def format_large_number(num)
    return '0' unless num

    case num
    when 0...1_000
      num.round(2).to_s
    when 1_000...1_000_000
      "#{(num / 1_000.0).round(1)}K"
    when 1_000_000...1_000_000_000
      "#{(num / 1_000_000.0).round(1)}M"
    else
      "#{(num / 1_000_000_000.0).round(2)}B"
    end
  end

  def format_change(change)
    return '0.00%' unless change

    formatted = format('%.2f', change.abs)
    if change >= 0
      "+#{formatted}%"
    else
      "-#{formatted}%"
    end
  end

  def format_change_colored(change)
    return colorize('0.00%', COLORS[:overlay0]) unless change

    formatted = format_change(change)

    if change >= 5
      colorize(formatted, COLORS[:green], bold: true)
    elsif change >= 2
      colorize(formatted, COLORS[:green])
    elsif change >= 0
      colorize(formatted, COLORS[:teal])
    elsif change >= -2
      colorize(formatted, COLORS[:peach])
    elsif change >= -5
      colorize(formatted, COLORS[:red])
    else
      colorize(formatted, COLORS[:red], bold: true)
    end
  end

  def format_trend_colored(trend_text)
    case trend_text
    when /trending up/
      colorize(trend_text, COLORS[:green])
    when /trending down/
      colorize(trend_text, COLORS[:red])
    else
      colorize(trend_text, COLORS[:yellow])
    end
  end

  def get_trend(prices)
    return nil unless prices && prices.length > 10

    recent = prices.last(24)
    first_half_avg = recent.first(12).sum / 12.0
    second_half_avg = recent.last(12).sum / 12.0

    if second_half_avg > first_half_avg * 1.02
      "↗ trending up"
    elsif second_half_avg < first_half_avg * 0.98
      "↘ trending down"
    else
      "→ sideways"
    end
  end

  def colorize(text, color, bold: false)
    text = escape_pango(text)
    markup = "<span foreground='#{color}'"
    markup += " weight='bold'" if bold
    markup += ">#{text}</span>"
    markup
  end

  def escape_pango(text)
    text.to_s
      .gsub('&', '&amp;')
      .gsub('<', '&lt;')
      .gsub('>', '&gt;')
  end
end

# Main execution
fetcher = CryptoFetcher.new
data = fetcher.fetch_data
formatter = CryptoFormatter.new(data)

puts JSON.generate(formatter.waybar_json)
