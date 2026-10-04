#!/usr/bin/env ruby
require 'json'

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

class SystemInfo
  def initialize
    @user = ENV['USER']
    @hostname = get_full_hostname
    @kernel = get_kernel_version
    @os_name = get_os_name
    @arch = get_arch
    @cpu_usage = get_cpu_usage
    @ram_info = get_ram_info
    @disk_info = get_all_disk_info
    @sensor_info = get_sensor_info
    @uptime = get_uptime
  end


  def waybar_text
    " #{@kernel}"
  end

  def waybar_tooltip
    lines = [
      format_header,
      "",
      format_cpu_section,
      "",
      format_memory_section,
      "",
      format_disk_section,
      "",
      format_sensor_section,
      "",
      format_uptime_section
    ]

    lines.join("\n")
  end

  def waybar_json
    {
      text: waybar_text,
      tooltip: waybar_tooltip,
      class: 'sysinfo'
    }
  end

  private

  def get_full_hostname
    # Get FQDN (Fully Qualified Domain Name)
    fqdn = `hostname -f 2>/dev/null`.strip
    # Fallback to regular hostname if FQDN fails
    fqdn.empty? ? `hostname`.strip : fqdn
  end

  def get_kernel_version
    `uname -r`.strip
  end

  def get_os_name
    # Get just the distro name (e.g., "Arch Linux")
    `grep "^NAME=" /etc/os-release | cut -d'=' -f2`.strip
  end

  def get_arch
    `uname -m`.strip
  end

  def get_cpu_usage
    # Get overall CPU usage
    cpu_stats = `top -bn2 -d 0.5 | grep "Cpu(s)" | tail -1`.strip
    if cpu_stats =~ /(\d+\.\d+)\s*id/
      idle = $1.to_f
      (100 - idle).round(1)
    else
      0
    end
  end

  def get_ram_info
    mem_info = {}
    File.readlines('/proc/meminfo').each do |line|
      if line =~ /^(\w+):\s+(\d+)/
        mem_info[$1] = $2.to_i
      end
    end

    total = mem_info['MemTotal'] / 1024.0
    available = mem_info['MemAvailable'] / 1024.0
    used = total - available
    cached = (mem_info['Cached'] + mem_info['SReclaimable']) / 1024.0
    buffers = mem_info['Buffers'] / 1024.0

    {
      total: total,
      used: used,
      available: available,
      cached: cached,
      buffers: buffers,
      percent: ((used / total) * 100).round(1)
    }
  end

  def get_all_disk_info
    disks = []

    # Get df output for all mounted filesystems
    # Avoid network/fuse mounts here. A stale hard NFS mount can leave df stuck
    # in D-state, which freezes Waybar's custom module process.
    df_output = `df -h -x tmpfs -x devtmpfs -x squashfs -x overlay -x nfs -x nfs4 -x cifs -x fuse -x fuse.sshfs -x fuse.portal 2>/dev/null`.lines

    # Skip header
    df_output[1..-1].each do |line|
      parts = line.split
      next if parts.length < 6

      filesystem = parts[0]
      size = parts[1]
      used = parts[2]
      available = parts[3]
      percent = parts[4].to_i
      mountpoint = parts[5..-1].join(' ')

      # Skip if not a real device (but include mapper devices)
      next unless filesystem.start_with?('/dev/') || filesystem.include?('mapper')

      # Determine disk type and get a friendly name
      type, icon, color = get_disk_type_info(filesystem, mountpoint)

      disks << {
        filesystem: filesystem,
        mountpoint: mountpoint,
        size: size,
        used: used,
        available: available,
        percent: percent,
        type: type,
        icon: icon,
        color: color
      }
    end

    disks
  end

  def get_disk_type_info(filesystem, mountpoint)
    case
    when filesystem.include?('mapper')
      if mountpoint == '/'
        ['encrypted root', '', COLORS[:yellow]]
      elsif mountpoint == '/home'
        ['encrypted home', '', COLORS[:green]]
      else
        ['encrypted', '', COLORS[:yellow]]
      end
    when filesystem.include?('nvme')
      ['nvme ssd', '', COLORS[:sapphire]]
    when filesystem.include?('sd')
      ['sata disk', '', COLORS[:blue]]
    when mountpoint == '/'
      ['root', '', COLORS[:yellow]]
    when mountpoint == '/home'
      ['home', '', COLORS[:green]]
    when mountpoint == '/boot'
      ['boot', '', COLORS[:peach]]
    when mountpoint.start_with?('/mnt') || mountpoint.start_with?('/media')
      ['external', '', COLORS[:teal]]
    else
      ['disk', '', COLORS[:lavender]]
    end
  end

  def get_sensor_info
    sensors_output = `sensors 2>/dev/null`

    info = {
      k10temp: {},
      amdgpu: {},
      z53: {}
    }

    current_device = nil

    sensors_output.lines.each do |line|
      case line
      when /k10temp-pci/
        current_device = :k10temp
      when /amdgpu-pci/
        current_device = :amdgpu
      when /Tctl:\s+\+([\d.]+)/
        info[:k10temp][:tctl] = $1.to_f if current_device == :k10temp
      when /fan1:\s+(\d+) RPM/
        info[:amdgpu][:fan] = $1.to_i if current_device == :amdgpu
      when /edge:\s+\+([\d.]+)/
        info[:amdgpu][:edge] = $1.to_f if current_device == :amdgpu
      when /junction:\s+\+([\d.]+)/
        info[:amdgpu][:junction] = $1.to_f if current_device == :amdgpu
      when /mem:\s+\+([\d.]+)/
        info[:amdgpu][:mem] = $1.to_f if current_device == :amdgpu
      end
    end

    # Add VRAM info
    info[:amdgpu].merge!(get_gpu_vram_info)

    # Get AIO info from liquidctl
    info[:z53] = get_liquidctl_info

    info
  end

def get_liquidctl_info
  aio_info = {}

  begin
    # Match Z63 specifically and get status
    liquidctl_output = `liquidctl --match "Z63" status 2>/dev/null`

    liquidctl_output.lines.each do |line|
      case line
      when /Liquid temperature\s+(\d+\.\d+)\s*°C/
        aio_info[:coolant] = $1.to_f
      when /Fan speed\s+(\d+)\s*rpm/
        aio_info[:fan] = $1.to_i
      when /Pump speed\s+(\d+)\s*rpm/
        aio_info[:pump] = $1.to_i
      when /Fan duty\s+(\d+)\s*%/
        aio_info[:fan_duty] = $1.to_i
      when /Pump duty\s+(\d+)\s*%/
        aio_info[:pump_duty] = $1.to_i
      end
    end
  rescue => e
    # Silently fail if liquidctl isn't available
  end

  aio_info
end

def get_gpu_vram_info
  vram_info = {}

  # Method 1: Try sysfs first (most reliable, no extra tools needed)
  begin
    # Find the GPU card (usually card0 or card1)
    card_dirs = Dir.glob('/sys/class/drm/card*/device')

    card_dirs.each do |card_dir|
      # Check if it's an AMD GPU
      vendor = File.read("#{card_dir}/vendor").strip rescue nil
      next unless vendor == '0x1002'  # AMD vendor ID

      # Try to read VRAM usage
      if File.exist?("#{card_dir}/mem_info_vram_used")
        vram_used_bytes = File.read("#{card_dir}/mem_info_vram_used").strip.to_i
        vram_total_bytes = File.read("#{card_dir}/mem_info_vram_total").strip.to_i rescue 0

        if vram_total_bytes > 0
          vram_info[:vram_used_mb] = (vram_used_bytes / 1024.0 / 1024.0).round(0)
          vram_info[:vram_total_mb] = (vram_total_bytes / 1024.0 / 1024.0).round(0)
          vram_info[:vram_percent] = ((vram_used_bytes.to_f / vram_total_bytes) * 100).round(1)
          break
        end
      end
    end
  rescue => e
    # Silently fail if sysfs method doesn't work
  end

  # Method 2: Fallback to radeontop if available and sysfs didn't work
  if vram_info.empty? && system('which radeontop > /dev/null 2>&1')
    begin
      # Run radeontop for 1 sample and parse output
      output = `radeontop -d - -l 1 2>/dev/null | tail -1`
      if output =~ /vram\s+([\d.]+)%\s+([\d.]+)mb/i
        vram_percent = $1.to_f
        vram_used = $2.to_f
        # Estimate total (this is approximate)
        vram_total = (vram_used / vram_percent * 100).round(0) if vram_percent > 0

        vram_info[:vram_used_mb] = vram_used.round(0)
        vram_info[:vram_total_mb] = vram_total if vram_total
        vram_info[:vram_percent] = vram_percent.round(1)
      end
    rescue => e
      # Silently fail
    end
  end

  # Method 3: Try reading from amdgpu debugfs (requires root or specific permissions)
  if vram_info.empty?
    begin
      debugfs_paths = Dir.glob('/sys/kernel/debug/dri/*/amdgpu_vram_mm')
      debugfs_paths.each do |path|
        content = File.read(path) rescue next
        if content =~ /size (\d+)MiB/m && content =~ /cur\s+(\d+)MiB/m
          vram_total = $1.to_i
          vram_used = $2.to_i

          vram_info[:vram_used_mb] = vram_used
          vram_info[:vram_total_mb] = vram_total
          vram_info[:vram_percent] = ((vram_used.to_f / vram_total) * 100).round(1)
          break
        end
      end
    rescue => e
      # Silently fail if we don't have permissions
    end
  end

  vram_info
end

  def get_uptime
    uptime_seconds = File.read('/proc/uptime').split[0].to_f
    days = (uptime_seconds / 86400).to_i
    hours = ((uptime_seconds % 86400) / 3600).to_i
    minutes = ((uptime_seconds % 3600) / 60).to_i

    {
      days: days,
      hours: hours,
      minutes: minutes,
      total_seconds: uptime_seconds
    }
  end

  # Header with user@hostname and system info on same line
  def format_header
    user_host = "#{@user}@#{@hostname}"
    system_info = "#{@os_name} #{@kernel} #{@arch}"

    "#{colorize(user_host, COLORS[:blue], bold: true)}  #{colorize('', COLORS[:overlay0])}  #{colorize(system_info, COLORS[:mauve])}"
  end

  def format_cpu_section
    color = usage_color(@cpu_usage)

    # Get CPU model
    cpu_model = `lscpu | grep "Model name" | cut -d: -f2`.strip
    cpu_model = cpu_model.gsub(/\s+/, ' ').gsub(/\(R\)|\(TM\)/, '') if cpu_model

    # Get core count
    cores = `nproc`.strip
    threads = `lscpu | grep "^CPU(s):" | awk '{print $2}'`.strip

    # Get CPU frequency
    freq = `cat /proc/cpuinfo | grep "cpu MHz" | head -1 | awk '{print $4}'`.strip.to_f
    freq_ghz = (freq / 1000.0).round(2)

    # Get load average
    loadavg = File.read('/proc/loadavg').split[0..2].join(', ')

    [
      "#{colorize('', COLORS[:peach])} #{colorize('cpu', COLORS[:peach], bold: true)}",
      "  #{colorize('model', COLORS[:subtext0])}      #{colorize(cpu_model, COLORS[:text])}",
      "  #{colorize('cores', COLORS[:subtext0])}      #{colorize("#{cores} cores / #{threads} threads", COLORS[:text])}",
      "  #{colorize('usage', COLORS[:subtext0])}      #{colorize("#{@cpu_usage}%", color)}",
      "  #{colorize('frequency', COLORS[:subtext0])}  #{colorize("#{freq_ghz} GHz", COLORS[:teal])}",
      "  #{colorize('load avg', COLORS[:subtext0])}   #{colorize(loadavg, COLORS[:overlay1])}"
    ].join("\n")
  end

  def format_memory_section
    ram = @ram_info
    color = usage_color(ram[:percent])

    # Create a simple bar
    bar_length = 20
    filled = (bar_length * ram[:percent] / 100.0).round
    bar = '█' * filled + '░' * (bar_length - filled)

    [
      "#{colorize('', COLORS[:green])} #{colorize('memory', COLORS[:green], bold: true)}",
      "  #{colorize('total', COLORS[:subtext0])}      #{colorize("#{format_size(ram[:total])}", COLORS[:text])}",
      "  #{colorize('used', COLORS[:subtext0])}       #{colorize("#{format_size(ram[:used])}", color)} #{colorize("(#{ram[:percent]}%)", COLORS[:overlay1])}",
      "  #{colorize('available', COLORS[:subtext0])}  #{colorize("#{format_size(ram[:available])}", COLORS[:teal])}",
      "  #{colorize('cached', COLORS[:subtext0])}     #{colorize("#{format_size(ram[:cached])}", COLORS[:overlay1])}",
      "  #{colorize('buffers', COLORS[:subtext0])}    #{colorize("#{format_size(ram[:buffers])}", COLORS[:overlay1])}",
      "  #{colorize(bar, color)}"
    ].join("\n")
  end

  def format_disk_section
    return "#{colorize('', COLORS[:yellow])} #{colorize('storage', COLORS[:yellow], bold: true)}\n  #{colorize('no disks found', COLORS[:overlay0])}" if @disk_info.empty?

    lines = [
      "#{colorize('', COLORS[:yellow])} #{colorize('storage', COLORS[:yellow], bold: true)}"
    ]

    @disk_info.each_with_index do |disk, index|
      lines << "" if index > 0  # Add spacing between disks
      lines << format_single_disk(disk)
    end

    lines.join("\n")
  end

  def format_single_disk(disk)
    color = usage_color(disk[:percent])

    # Create a simple bar
    bar_length = 20
    filled = (bar_length * disk[:percent] / 100.0).round
    bar = '█' * filled + '░' * (bar_length - filled)

    # Format the header with icon and type
    header = "  #{colorize(disk[:icon], disk[:color])} #{colorize(disk[:type], disk[:color], bold: true)}"

    # Format mountpoint
    mountpoint_display = if disk[:mountpoint].length > 30
      disk[:mountpoint][0..27] + "..."
    else
      disk[:mountpoint]
    end

    [
      header,
      "    #{colorize('mount', COLORS[:subtext0])}      #{colorize(mountpoint_display, COLORS[:overlay1])}",
      "    #{colorize('device', COLORS[:subtext0])}     #{colorize(disk[:filesystem], COLORS[:overlay1])}",
      "    #{colorize('total', COLORS[:subtext0])}      #{colorize(disk[:size], COLORS[:text])}",
      "    #{colorize('used', COLORS[:subtext0])}       #{colorize(disk[:used], color)} #{colorize("(#{disk[:percent]}%)", COLORS[:overlay1])}",
      "    #{colorize('available', COLORS[:subtext0])}  #{colorize(disk[:available], COLORS[:teal])}",
      "    #{colorize(bar, color)}"
    ].join("\n")
  end

  def format_sensor_section
    sensors = @sensor_info
    lines = []

    lines << "#{colorize('', COLORS[:red])} #{colorize('temperatures', COLORS[:red], bold: true)}"

    # CPU Temperature
    if temp = sensors[:k10temp][:tctl]
      color = temp_color(temp)
      lines << "  #{colorize('cpu (tctl)', COLORS[:subtext0])}    #{colorize("#{temp.round(1)}°C", color)}"
    end

    # GPU Section
    if sensors[:amdgpu][:edge]
      lines << ""
      lines << "  #{colorize('gpu:', COLORS[:mauve], bold: true)}"

      # GPU Fan
      if fan = sensors[:amdgpu][:fan]
        fan_percent = ((fan.to_f / 3300) * 100).round(0)
        fan_color = fan_percent < 40 ? COLORS[:green] : fan_percent < 70 ? COLORS[:yellow] : COLORS[:red]
        lines << "    #{colorize('fan', COLORS[:subtext0])}        #{colorize("#{fan} RPM", fan_color)} #{colorize("(#{fan_percent}%)", COLORS[:overlay1])}"
      end

      # GPU Temperatures
      if temp = sensors[:amdgpu][:edge]
        color = temp_color(temp)
        lines << "    #{colorize('edge', COLORS[:subtext0])}       #{colorize("#{temp.round(1)}°C", color)}"
      end

      if temp = sensors[:amdgpu][:junction]
        color = temp_color(temp)
        lines << "    #{colorize('junction', COLORS[:subtext0])}   #{colorize("#{temp.round(1)}°C", color)}"
      end

      if temp = sensors[:amdgpu][:mem]
        color = temp_color(temp)
        lines << "    #{colorize('mem', COLORS[:subtext0])}        #{colorize("#{temp.round(1)}°C", color)}"
      end

      # VRAM
      if vram_used = sensors[:amdgpu][:vram_used_mb]
        vram_percent = sensors[:amdgpu][:vram_percent] || 0
        vram_color = usage_color(vram_percent)

        if vram_total = sensors[:amdgpu][:vram_total_mb]
          vram_used_gb = (vram_used / 1024.0).round(2)
          vram_total_gb = (vram_total / 1024.0).round(2)
          lines << "    #{colorize('vram', COLORS[:subtext0])}       #{colorize("#{vram_used_gb} GiB", vram_color)} / #{colorize("#{vram_total_gb} GiB", COLORS[:text])} #{colorize("(#{vram_percent.round(1)}%)", COLORS[:overlay1])}"
        else
          vram_used_gb = (vram_used / 1024.0).round(2)
          lines << "    #{colorize('vram', COLORS[:subtext0])}       #{colorize("#{vram_used_gb} GiB", vram_color)}"
        end
      end
    end

    # AIO Section (Z63)
    if sensors[:z53][:coolant] || sensors[:z53][:pump] || sensors[:z53][:fan]
      lines << ""
      lines << "  #{colorize('aio (z63):', COLORS[:sky], bold: true)}"

      # Pump
      if pump = sensors[:z53][:pump]
        pump_color = pump > 2000 ? COLORS[:green] : pump > 1500 ? COLORS[:yellow] : COLORS[:red]

        if pump_duty = sensors[:z53][:pump_duty]
          pump_display = "#{pump} RPM (#{pump_duty}%)"
        else
          pump_display = "#{pump} RPM"
        end

        lines << "    #{colorize('pump', COLORS[:subtext0])}       #{colorize(pump_display, pump_color)}"
      end

      # Fan
      if fan = sensors[:z53][:fan]
        fan_duty = sensors[:z53][:fan_duty] || ((fan.to_f / 2500) * 100).round(0)
        fan_color = fan_duty < 40 ? COLORS[:green] : fan_duty < 70 ? COLORS[:yellow] : COLORS[:red]

        if sensors[:z53][:fan_duty]
          fan_display = "#{fan} RPM (#{fan_duty}%)"
        else
          fan_display = "#{fan} RPM"
        end

        lines << "    #{colorize('fan', COLORS[:subtext0])}        #{colorize(fan_display, fan_color)}"
      end

      # Coolant Temperature
      if temp = sensors[:z53][:coolant]
        color = temp_color(temp)
        lines << "    #{colorize('coolant', COLORS[:subtext0])}    #{colorize("#{temp.round(1)}°C", color)}"
      end
    end

    lines.join("\n")
  end

  def format_uptime_section
    uptime_str = []
    uptime_str << "#{@uptime[:days]}d" if @uptime[:days] > 0
    uptime_str << "#{@uptime[:hours]}h" if @uptime[:hours] > 0
    uptime_str << "#{@uptime[:minutes]}m"

    [
      "#{colorize('', COLORS[:lavender])} #{colorize('uptime', COLORS[:lavender], bold: true)}",
      "  #{colorize(uptime_str.join(' '), COLORS[:text])}"
    ].join("\n")
  end

  def mini_bar(percent, length, max = 100)
    filled = [(length * [percent, max].min / max.to_f).round, length].min
    '█' * filled + '░' * (length - filled)
  end

  def format_size(mb)
    if mb >= 1024
      "#{(mb / 1024.0).round(1)}G"
    else
      "#{mb.round(0)}M"
    end
  end

  def usage_color(percent)
    case percent
    when 0..50 then COLORS[:green]
    when 51..70 then COLORS[:yellow]
    when 71..85 then COLORS[:peach]
    else COLORS[:red]
    end
  end

  def temp_color(temp)
    case temp
    when 0..45 then COLORS[:green]
    when 46..60 then COLORS[:teal]
    when 61..70 then COLORS[:yellow]
    when 71..80 then COLORS[:peach]
    else COLORS[:red]
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
sysinfo = SystemInfo.new
puts JSON.generate(sysinfo.waybar_json)
