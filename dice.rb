if ARGV.size < 2
  puts "expects arguments <count> <sides> [window length] [clamp_factor] [graph_width]"
  exit
end

$count = ARGV[0].to_i
$sides = ARGV[1].to_i
$window = ARGV.length > 2 ? ARGV[2].to_i : 40
$clamp_factor = ARGV.length > 3 ? ARGV[3].to_f : 3
$graph_width = ARGV.length > 4 ? ARGV[4].to_i : 65
$graph_scale = 1.5

$base_frequency = {}

$history = {}

def generate_base_counts(dice, total)
  if dice == 0
    unless $base_frequency.has_key? total
      $base_frequency[total] = 0
    end

    $base_frequency[total] += 1
    return
  end

  (1..$sides).each do |roll|
    generate_base_counts(dice-1, total+roll)
  end
end

def generate_base_distribution
  generate_base_counts($count, 0)
  total = $base_frequency.values.sum
  puts "this dice set has #{total} outcomes, #{$base_frequency.size} unique"

  $base_frequency.each do |outcome, frequency|
    $base_frequency[outcome] = frequency/(total.to_f)
  end
end

def build_plan
  goals = {}
  probs = {}

  $base_frequency.each do |outcome, frequency|
    goals[outcome] = $base_frequency[outcome] * ($history.values.sum + $window)
    if $history.has_key? outcome
      goals[outcome] -= $history[outcome]
    end
    probs[outcome] = goals[outcome]/$window.to_f
  end

  floating = []
  fixed = []

  probs.each do |outcome, prob|
    if prob <= $base_frequency[outcome] / $clamp_factor
      probs[outcome] = $base_frequency[outcome] / $clamp_factor
      fixed.push outcome
    else
      floating.push outcome
    end
  end

  prob_available = 1 - fixed.map{|f| probs[f]}.sum
  total_weight = floating.map{|f| probs[f]}.sum

  floating.map do |outcome|
    probs[outcome] = probs[outcome] * prob_available / total_weight
  end
  
  if fixed.length > 0
    puts "outcomes #{fixed} clamped at their minimum frequency (1/#{$clamp_factor} of natural frequency)"
  end

  return probs
end

def print_graph(probs)
  lines = []

  x_scale = $base_frequency.values.max * $graph_scale

  probs.each do |outcome, prob|
    line = [' '] * $graph_width
    free = [true] * $graph_width
    extra_lines = []

    base_mark = ($base_frequency[outcome] * $graph_width / x_scale).round
    bar_mark = (prob * $graph_width / x_scale).round

    (0...bar_mark).each do |i|
      if i < $graph_width
        line[i] = '='
      end
    end

    line[0] = '['
    free[0] = false
    free[1] = false

    if base_mark < $graph_width
      line[base_mark] = '+'
      free[base_mark] = false
    end

    if bar_mark < $graph_width
      line[bar_mark] = ']'
      free[bar_mark] = false
      free[bar_mark + 1] = false
      free[[0, bar_mark-1].max] = false
    else
      label = "(+#{bar_mark - $graph_width + 1})"
      index = $graph_width - label.length
      if index >= 0
        label.split('').each do |chr|
          line[index] = chr
          free[index] = false
          index += 1
        end
      else
        extra_lines.push label
      end
    end

    label = "#{outcome}: #{ (prob * 100).round}%"
    location = nil
    (0...$graph_width).each do |index|
      positions = (index-1)...(index + label.size + 1)
      positions_free = positions.map do |pos|
        pos >= 0 && pos < $graph_width && free[pos]
      end

      if positions_free.all?
        location = index
        break
      end
    end

    if location == nil
      extra_lines.push label
    else
      label.split('').each do |chr|
        line[location] = chr
        free[location] = false
        location += 1
      end
    end

    lines.push (['| '] + line + [' |'])

    extra_lines.each do |extra_line|
      extra_line = '>' + extra_line + (' ')*[0, ($graph_width - extra_line.length)].max + '<'
      lines.push extra_line.split('')
    end

  end

  puts "current probabilities:"

  print "+-" + ('-' * $graph_width) + "-+\n"

  lines.each do |line|
    line.each do |char|
      print char
    end
    print "\n"
  end

  print "+-" + ('-' * $graph_width) + "-+\n"

end

def display(probs)
  unless $history.empty?
    tokens = []
    $history.keys.sort.each do |outcome|
      token = outcome.to_s
      if $history[outcome] > 1
        token += "x#{$history[outcome]}"
      end
      tokens.push token
    end

    print "history: #{tokens.join(', ')} (#{$history.values.sum} total rolls)"
    puts
  end
  print_graph(probs)
end

def do_roll(probs)
  r = rand
  choice = nil
  probs.each do |outcome, prob|
    r -= prob
    if r <= 0
      choice = outcome
      break
    end
  end

  if choice == nil
    throw "failed to select a roll"
  end
  
  unless $history.has_key? choice
    $history[choice] = 0
  end

  $history[choice] += 1
  return choice
end

def run_dice
  generate_base_distribution

  while true
    probs = build_plan
    display(probs)
    puts "ready to roll"
    STDIN.gets
    puts "\n" * 30
    roll = do_roll(probs)
    puts "rolled #{roll}"
  end
end

run_dice
