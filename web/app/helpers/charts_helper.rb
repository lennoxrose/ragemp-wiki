# Inline SVG charts for the admin pages. Drawn server side so they work without JavaScript.
module ChartsHelper
  CHART_COLORS = %w[#FFCF31 #FF8A3D #5ED6B3 #6B6B6B].freeze

  # Smooth line through points (Catmull-Rom converted to Bezier curves).
  def smooth_path(points)
    return "" if points.empty?
    d = +"M#{points[0][0].round(1)},#{points[0][1].round(1)}"
    (0...points.size - 1).each do |i|
      p0 = points[i - 1] || points[i]
      p1 = points[i]
      p2 = points[i + 1]
      p3 = points[i + 2] || p2
      c1 = [p1[0] + (p2[0] - p0[0]) / 6.0, p1[1] + (p2[1] - p0[1]) / 6.0]
      c2 = [p2[0] - (p3[0] - p1[0]) / 6.0, p2[1] - (p3[1] - p1[1]) / 6.0]
      d << " C#{c1[0].round(1)},#{c1[1].round(1)} #{c2[0].round(1)},#{c2[1].round(1)} #{p2[0].round(1)},#{p2[1].round(1)}"
    end
    d
  end

  # 1, 2, 5 times a power of ten that covers the value
  def nice_max(value)
    return 4 if value <= 0
    exp = 10**Math.log10(value).floor
    [1, 2, 2.5, 5, 10].map { |m| m * exp }.find { |c| c >= value } || value
  end

  def sparkline(values, color, width: 84, height: 34)
    values = [0, 0] if values.size < 2
    max = values.max.to_f
    min = values.min.to_f
    range = max == min ? 1.0 : max - min
    pts = values.each_with_index.map { |v, i| [2 + i * (width - 4.0) / (values.size - 1), height - 3 - ((v - min) / range) * (height - 6)] }
    tag.svg(tag.path(d: smooth_path(pts), stroke: color, "stroke-width": 1.6, "stroke-linecap": "round", fill: "none"),
            width: width, height: height, viewBox: "0 0 #{width} #{height}", "aria-hidden": "true", class: "spark")
  end

  # Stacked area chart. series: [{name:, values: []}] drawn bottom to top. Returns [svg, y_labels].
  def stacked_area(series, width: 756, height: 234)
    n = series.first ? series.first[:values].size : 0
    return [nil, []] if n < 2
    stacks = series.each_with_index.map { |_, i| (0...n).map { |j| series[0..i].sum { |s| s[:values][j] } } }
    max = nice_max(stacks.last.max)
    top, bottom = 7, height - 7
    x = ->(j) { j * width.to_f / (n - 1) }
    y = ->(v) { bottom - (v.to_f / max) * (bottom - top) }
    grid = (0..4).map { |g| line = y.call(max * g / 4.0); tag.line(x1: 0, y1: line, x2: width, y2: line, stroke: "#262626", "stroke-width": 1) }
    areas = series.each_index.to_a.reverse.map do |i|
      pts = stacks[i].each_with_index.map { |v, j| [x.call(j), y.call(v)] }
      color = CHART_COLORS[i % CHART_COLORS.size]
      id = "area-#{i}"
      defs = tag.linearGradient(safe_join([tag.stop(offset: 0, "stop-color": color, "stop-opacity": 0.38), tag.stop(offset: 1, "stop-color": color, "stop-opacity": 0.02)]), id: id, x1: 0, y1: 0, x2: 0, y2: 1)
      line = smooth_path(pts)
      safe_join([defs, tag.path(d: "#{line} L#{width},#{bottom} L0,#{bottom} Z", fill: "url(#area-#{i})"), tag.path(d: line, stroke: color, "stroke-width": 1.8, fill: "none", "stroke-linejoin": "round")])
    end
    svg = tag.svg(safe_join(grid + areas), width: "100%", viewBox: "0 0 #{width} #{height}", preserveAspectRatio: "none", class: "chart-svg", "aria-hidden": "true")
    [svg, (0..4).map { |g| delimited((max * (4 - g) / 4.0).round) }]
  end

  # Two lines (peak and average) over 24 hours.
  def hourly_lines(rows, width: 340, height: 168)
    max = nice_max([rows.map { |r| r[:peak] }.max.to_i, 1].max)
    top, bottom = 6, height - 6
    x = ->(i) { i * width.to_f / 23 }
    y = ->(v) { bottom - (v.to_f / max) * (bottom - top) }
    grid = (0..3).map { |g| line = y.call(max * g / 3.0); tag.line(x1: 0, y1: line, x2: width, y2: line, stroke: "#262626", "stroke-width": 1) }
    paths = [[:peak, "#FFCF31"], [:avg, "#FF8A3D"]].each_with_index.map do |(key, color), k|
      pts = rows.each_with_index.map { |r, i| [x.call(i), y.call(r[key])] }
      line = smooth_path(pts)
      defs = tag.linearGradient(safe_join([tag.stop(offset: 0, "stop-color": color, "stop-opacity": 0.32), tag.stop(offset: 1, "stop-color": color, "stop-opacity": 0.02)]), id: "hour-#{k}", x1: 0, y1: 0, x2: 0, y2: 1)
      safe_join([defs, tag.path(d: "#{line} L#{width},#{bottom} L0,#{bottom} Z", fill: "url(#hour-#{k})"), tag.path(d: line, stroke: color, "stroke-width": 1.8, fill: "none")])
    end
    [tag.svg(safe_join(grid + paths), width: "100%", viewBox: "0 0 #{width} #{height}", preserveAspectRatio: "none", class: "chart-svg", "aria-hidden": "true"),
     (0..3).map { |g| (max * (3 - g) / 3.0).round.to_s }]
  end

  def donut(parts, size: 160, radius: 62, stroke: 20)
    total = parts.sum { |_, n| n }.to_f
    total = 1.0 if total.zero?
    angle = -Math::PI / 2
    gap = 0.05
    arcs = parts.each_with_index.map do |(_, n), i|
      next if n.zero?
      span = n / total * Math::PI * 2
      a0 = angle + gap / 2
      a1 = angle + span - gap / 2
      angle += span
      c = size / 2.0
      pt = ->(a) { [c + radius * Math.cos(a), c + radius * Math.sin(a)] }
      x0, y0 = pt.call(a0)
      x1, y1 = pt.call(a1)
      tag.path(d: "M#{x0.round(2)},#{y0.round(2)} A#{radius},#{radius} 0 #{(a1 - a0) > Math::PI ? 1 : 0} 1 #{x1.round(2)},#{y1.round(2)}", stroke: CHART_COLORS[i % CHART_COLORS.size], "stroke-width": stroke, fill: "none")
    end
    tag.svg(safe_join(arcs.compact), width: size, height: size, viewBox: "0 0 #{size} #{size}", "aria-hidden": "true", class: "donut")
  end

  def month_bars(rows, width: 330, height: 150)
    max = [rows.map { |r| r[1] }.max, 1].max
    n = rows.size
    bw = [(width / n * 0.55).floor, 22].min
    gap = (width - n * bw).to_f / (n - 1)
    defs = tag.linearGradient(safe_join([tag.stop(offset: 0, "stop-color": "#FFCF31"), tag.stop(offset: 1, "stop-color": "#FFCF31", "stop-opacity": 0.15)]), id: "bars", x1: 0, y1: 0, x2: 0, y2: 1)
    rects = rows.each_with_index.map do |(_, v, label), i|
      h = (v.to_f / max) * (height - 4)
      tag.rect(x: (i * (bw + gap)).round(1), y: (height - h).round(1), width: bw, height: h.round(1), rx: 4, fill: "url(#bars)").then { |r| tag.title(label + ": " + v.to_s).then { |t| tag.g(safe_join([t, r])) } }
    end
    tag.svg(safe_join([defs] + rects), width: "100%", viewBox: "0 0 #{width} #{height}", preserveAspectRatio: "none", class: "chart-svg", role: "img", "aria-label": "New accounts per month")
  end

  # 7 x 24 cells, five levels of yellow.
  def heatmap_svg(grid, pitch: 16.4, cell: 13)
    max = [grid.flatten.max, 1].max
    levels = %w[#1c1c1c #4a3d10 #7d6618 #c29f24 #FFCF31]
    cells = grid.each_with_index.flat_map do |row, r|
      row.each_with_index.map do |v, h|
        ratio = v.to_f / max
        lvl = v.zero? ? 0 : (ratio < 0.25 ? 1 : ratio < 0.5 ? 2 : ratio < 0.8 ? 3 : 4)
        tag.rect(x: (h * pitch).round(1), y: (r * pitch).round(1), width: cell, height: cell, rx: 3, fill: levels[lvl])
      end
    end
    tag.svg(safe_join(cells), width: "100%", viewBox: "0 0 #{(24 * pitch).ceil} #{(7 * pitch).ceil}", class: "heat-svg", role: "img", "aria-label": "Page views by weekday and hour")
  end
end
