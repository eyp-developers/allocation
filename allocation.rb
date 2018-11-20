# Weighted preferences allocation command line tool
# @author Samuel Hönle <samuel.hoenle@eyp.at>

=begin
    Format of preferences: (w1..w4 are weights as real numbers)
    Name,Topic 1,Topic 2
    Person 1,w1,w2
    Person 2,w3,w4
=end

require "CSV"
require "pp"
require "optparse"
require "pathname"

# Check if help is required or if debug messages should be printed
$debug = false
OptionParser.new do |opt|
    opt.on('-h') do
        puts "Weighted preferences allocation\nUsage: ruby " + __FILE__ + "[-h] [-v] path/to/file\nFormat of preferences: (w1..w4 are weights as real numbers)\nName,Topic 1,Topic 2\nPerson 1,w1,w2\nPerson 2,w3,w4"
        exit
        end
    opt.on('-v') { $debug = true }
end.parse!

# Set file path and abort if wrong argument
abort("Please pass the CSV file as the only argument") if ARGV.length != 1
path = Pathname(ARGV[0])
abort("Given file does not exist") unless path.exist?

# Read preferences and save them into global variables
$preferences = Hash.new
CSV.foreach(path, headers: true) do |row|
    $preferences[row["Name"]] = row.to_hash
    $preferences[row["Name"]].delete("Name")
end
$people = $preferences.keys
$choices = $preferences.values[0].keys

# Abort if there's not enough choices (#rows>#cols)
abort("Not enough choices for all people") if $choices.length < $people.length

# Variables to save optimal solution
$highscore = 0
$optimum = Hash.new

# Calculate score of a given allocation
def calculate_score(allocation)
    score = 0
    allocation.each{|person, assigned| score = score+$preferences[person][assigned].to_r}
    score
end

# Checks if highscore can possibly be reached with allocation
$max_pref = 0
$preferences.each { |person,prefs| prefs.each { |choice,score| $max_pref=score.to_r if score.to_r>$max_pref} }
def continue?(allocation, pers_i)
    score_fix = 0
    score_fix = calculate_score allocation.reject { |person| !$people[0..pers_i].include?(person)} unless pers_i==0 
    score_max = score_fix + ($people.length-pers_i)*$max_pref
    score_max >= $highscore
end

# Recursive method to find best allocation
def fill(current, pers_i)
    # If one of the previous people has not been allocated, there is no solution
    has_solution = true
    $people[0..pers_i-1].each { |person| has_solution = has_solution && !current[person].nil? } unless pers_i == 0

    # When leaf is reached, 
    if has_solution && pers_i == $people.length
        this_score = calculate_score current
        if this_score == $highscore
            $optimum  = [$optimum, current.clone]
            puts "Found another one with score #{this_score}" if $debug
            puts $optimum if $debug
        elsif this_score > $highscore
            $highscore = this_score
            $optimum = current.clone
            puts "Found one with score #{this_score}" if $debug
            puts $optimum if $debug
        end
    # Continue recursion down the solution tree if solution exists, abort otherwise
    elsif has_solution
        # Try choices sorted by weight
        ordered = $preferences[$people[pers_i]].sort_by {|k,v| v }.reverse
        ordered.each do |choice|
            # If choice has not been allocated before, continue recursion
            previous = current
            previous = current.reject { |person| !$people[0..pers_i-1].include?(person)} unless pers_i==0
            unless previous.values.include?(choice[0])
                current[$people[pers_i]] = choice[0]
                fill(current, pers_i+1) if continue?(current,pers_i) # continue recursion only if highscore can possibly be reached
                current[$people[pers_i]] = nil
            end
        end
    end
end

# Do recursion
fill(Hash.new, 0)

# Print solution
puts "Score: #{$highscore} with solution:"
pp $optimum
