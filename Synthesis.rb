require 'set'
require_relative 'FD'
require_relative 'Relation'


# Code by: Matt Antonelli

def exclude_fd(fd, f) # Returns F minus a specific FD
  f = f.dup
  f.each do |fd_check|
    if fd.x == fd_check.x && fd.multi == fd_check.multi && fd.y == fd_check.y
      return f.delete(fd_check) # Return F with removed FD
    end
  end
  return f # FD not found - return original F
end

def find_dep(x, rel)  # Calculates the dependency basis of x in reference to the given relation
  rel = rel.clone
  s = Set.new [rel.u - x]
  
  # 1. Change all FDs to MVDs
  rel.f.each do |fd|
    fd.set_multi(true)
  end
  
  # 2. Check (Y intersect W == empty) and (Y intersect V != empty) for each MVD
  old_y = Set.new
  new_y = Set.new
  rel.f.each do |mvd|
    s.each do |y|
      if (y & mvd.y).size > 0 && (y & mvd.x).size == 0
        old_y = y
        new_y.add(y & mvd.y)
        new_y.add(y - mvd.y)
        break
      end
    end
    if new_y.size > 0
      s.delete(old_y)
      s.merge(new_y)
      old_y.clear
      new_y.clear
      next
    end
  end

  s.delete_if { |e| e.empty? }  # Removes any empty sets
  
  puts "\nFinal result of DEP"
  s.each do |mvd|
    print_set(mvd)
  end
  puts ""
  
  return s  # Return the resulting dependency basis
end

def find_minimal_set(rel) # Returns the relation as a minimal set
  f = rel.f.dup
  new_set = Set.new
  f.each do |fd|
    if !fd.multi  # Do not reduce MVDs in the minimal set
      fd.y.each do |y|  # Canonize the right-side of the FD
        new_set.add( FD.new(fd.x, (Set.new [y]), false) )
      end
    else
      new_set.add(fd) # Add MVDs to set without modification
    end
  end
  
  f.clear # Clear original set
  f.merge(new_set)  # Add all values of new set
  
  new_set.clear  
  f.each do |fd|
    if !fd.multi && fd.x.size > 1 # Must be FD and |x| > 1
      new_set.add(reduce_left(fd, f)) # Attempt to reduce x
    else
      new_set.add(fd) # If not an FD or |x| == 1, add to set as is
    end
  end
  
  f.clear
  f.merge(new_set)
  
  f_copy = Set.new.merge(f)
  f.each do |fd|
    if !fd.multi  # Do not worry about MVDs
      x = fd.x
      x_plus = find_xclosure(x, exclude_fd(fd, f_copy))
      if fd.y.subset?x_plus # If X+ can still find the Y values without the FD in question
        f_copy.delete(fd) # Remove the FD from the set
      end
    end
  end
  
  f.clear
  f.merge(f_copy)

  return Relation.new(f)
end

def find_xclosure(x, f) # Calculates X+ for x in reference to the given F
  x_plus = Set.new.merge(x)
  old_x = Set.new
  begin
    old_x.clear
    old_x.merge(x_plus)
    f.each do |fd|
      if fd.x.subset?(x_plus) && !fd.multi  # If the FD is not an MVD and its X is a subset of X+
        x_plus.merge(fd.y)  # Add the Y values of the FD to X+
      end
    end
  end while x_plus != old_x
  return x_plus
end

def is_bcnf?(fd, rel) # Determines whether an FD in reference to a minimal set can determine all attributes
  minimal_set = find_minimal_set(rel)
  if !minimal_set.u.subset?(find_xclosure(fd.x, minimal_set.f)) # If X+ does not contain U of the minimal set
    return false  # The FD is preventing the relation from being in BCNF
  end
  return true # If X+ contains U of the minimal set, the FD is not preventing the relation from being in BCNF
end

def is_nontrivial?(mvd, rel)  # Determines whether or not an MVD is non-trivial
  return !(mvd.y.size == 0 || rel.u.subset?(mvd.y) || mvd.y.subset?(mvd.x))
end

def is_superkey?(x, rel)  # Determines whether or not an MVD is a superkey of the given relation
  dep_basis = find_dep(x, rel)
  if dep_basis.include?(rel.u)
    rel.each do |fd|
      if !fd.multi && !rel.u.include?(fd.x) && fd.y.subset?(rel.u)
        return true
      end
    end
  end
  return false
end

def print_set(set)  # Prints the values of the given set
  set.each do |x|
    $stdout.print x
  end
end

def read_fds(file)  # Reads FDs from the file. File must end with a line break or space!
  fds = Set.new
  begin
    if !/.txt/.match(file)
      raise "Input must be a .txt file!"
    end
    File.open(file, 'r') do |f|
      while line = f.gets
      if line.size < 3 
        raise line
      end
      if !(/\A[[:alpha:]]+>{1,2}(([[:alpha:]]*)|0)\Z/.match(line))  # Regex
        raise line.chomp + " is not properly formatted!"
      end
      count = 0
      for i in 0...line.size
        if line[i] == '>'
          count += 1
        end
      end
      if count < 1 || count > 2
        raise line.chomp + " is not properly formatted!"
      end
      sep = line.index('>')
      multi = line.count('>') == 2 ? true : false
     
      x = Set.new
      for i in 0...sep
        x.add(line[i])
      end
      
      y = Set.new
      for i in (sep + (multi ? 2 : 1))...(line.size - 1)
        y.add(line[i])
      end
      if y.size == 0
        y.add('0')
      end
  
      fds.add(FD.new(x, y, multi))
      end
    end
  rescue Exception => e
    puts e.message
    exit
  end
  return fds
end

def reduce_left(fd, f)  # Reduces left side of an FD
  original_fd = fd.clone
  original_fd.x.each do |x|
    new_fd = fd.clone
    new_fd.remove_x(x)
    x_plus = find_xclosure(new_fd.x, exclude_fd(original_fd, f))
    if fd.y.subset?x_plus # If the X+ of the FD minus attribute X still contains all Y values
      fd = new_fd.clone # Set the FD to the tested FD with the removed value
      if new_fd.x.size == 1
        return new_fd
      end
    end
  end
  return fd
end

def synth_3nf(rel)
  rel = find_minimal_set(rel)  # 1. Calculate the minimal set for the relation
  
  # 2. Find key. This operation is automatically done within the Relation class.
  
  # 3. Break into multiple relations that share the same determinant.
  rels = Set.new
  fds = rel.f.to_a
  rel.f.each do |fd|
    rel_fds = Set.new
    fd_copy = Array.new(fds)
    for i in 0...fd_copy.size
      if fd_copy[i].x == fd.x
        rel_fds.add(fd_copy[i])
        fds.delete(fd_copy[i])
      end
    end
    if rel_fds.size > 0 
      rels.add(Relation.new(rel_fds))
    end
  end
  
  # 4. If the key is not contained within any of the relations, add a relation containing the key.
  contains_key = false
  rels.each do |r|
    if rel.key.subset?r.u
      contains_key = true
      break
    end
  end
  if !contains_key
    rels.add(Relation.new(Set.new [FD.new(rel.key, nil, false)]))
  end
  
  # 5. Remove redundant relations (those where the U of one is the subset of another) by merging FDs
  new_rels = Set.new
  rels_copy = Set.new.merge(rels)
  rels.each do |r|
    new_fds = Set.new
    new_rel = Relation.new(Set.new.merge(r.f))
    duplicates = Set.new
    rels_copy.each do |s|
      if s != r && s.u.subset?(r.u) # If the relation is not comparing to itself and its U is a subset of the compared's U
        duplicates.add(s) # Add the relation to a set of duplicates to be removed
        s.f.each do |fd|
          new_fds.add(fd) # Add each of the relation's FD to a set
        end
      end
    end
    rels.subtract(duplicates) # Remove the duplicate relations
    new_fds.merge(r.f)  # Merge these FDs with those in the comparing relation
    new_rels.add(Relation.new(new_fds)) # Add a new relation containing the merged relations
  end
  
  return new_rels # Return set of relations in 3NF
end

def synth_bcnf(rel)
  rel = rel.clone
  original_f = rel.f.dup
  new_rels = Set.new.add(rel)
  begin
    all_bcnf = true
    new_fds = Set.new
    rel.f.each do |fd|
      # If the FD is not an MVD, does not determine empty set, and fails the BCNF requirement
      if !fd.y.include?('0') && !is_bcnf?(fd, rel.clone)
        new_rels.add(Relation.new(Set.new [fd.clone]))  # Add it to its own relation
        new_fds = rel.remove_att(fd, fd.y)  # Remove its y-value from the original relation
        all_bcnf = false  # Set the loop to continue
        break
      end
    end
    if !all_bcnf
      new_f = Set.new
      new_fds.each do |fd|
        if fd.y.include?('0')
          new_rels.add(Relation.new(Set.new [fd.clone]))  # Move FDs determining empty set to their own relations
        else
          new_f.add(fd) # Otherwise, just keep the FD in the original relation
        end
      end
      rel.set_f(new_f)  # Update the original relation to the new FDs
    end
  end while all_bcnf == false

  new_f = Set.new
  remove_set = Set.new
  new_rels.each do |r|
    new_f.merge(r.f)
    if r.u.size == 0
      remove_set.add(r) # Find relations that were left with nil values
    end
  end
  new_rels.subtract(remove_set) # Remove empty relations
  
  return [new_rels, (original_f - new_f)] # Return the set of relations in BCNF & set of lost FDs
end

def synth_4nf(rel)
  rel = rel.clone
  original_f = rel.f.dup  
  new_rels = Set.new.add(rel)
  begin
    change_mvd = nil
    no_change = true
    rel.f.each do |mvd|
      # If the MVD is non-trivial and is not a superkey
      if mvd.multi && is_nontrivial?(mvd, rel) && !is_superkey?(mvd.x, rel)
        change_mvd = mvd.clone  # Set the MVD to reference
        no_change = false # Set the loop to continue
        break
      end
    end
    if !no_change
      new_rels.add(Relation.new(Set.new [change_mvd]))  # Add the MVD to its own relation
      rel.f.delete(change_mvd)  # Delete the MVD from the original relation
      new_fds = rel.remove_att(change_mvd, change_mvd.y)  # Remvoe its y-value from the original relation
      new_f = Set.new
      new_fds.each do |fd|
        if fd.y.include?('0')
          new_rels.add(Relation.new(Set.new [fd.clone]))  # Move FDs determining empty set to their own relations
        else
          new_f.add(fd) # Otherwise, just keep the FD in the original relation
        end
      end
      rel.set_f(new_f)  # Update the original relation to the new FDs
    end
  end while !no_change
  
  new_rels.add(rel)
  
  new_f = Set.new
  remove_set = Set.new
  new_rels.each do |r|
    new_f.merge(r.f)
    if r.u.size == 0
      remove_set.add(r) # Find relations that were left with nil values
    end
  end
  new_rels.subtract(remove_set) # Remove empty relations
  
  return [new_rels, (original_f - new_f)] # Return the set of relations in 4NF & set of lost FDs
end

puts "Provide a path for a .txt file containing your FDs."
puts "The FDs should be formatted as: AB>C, A>>BC, A>0, or A>"
puts "You must include a blank line at the end of your file!"
print "\nEnter the file path: "
file = gets.chomp
rel = Relation.new(read_fds(file))  # Read FDs from file and create a relation R(U, F)
puts "\nOriginal relation:"
rel.print

contains_multi = false
rel.f.each do |fd|
  if fd.multi
    contains_multi = true
    break
  end
end

while true
  puts "\nWhat would you like to do with your relation?"
  puts "a) Decompose into 3NF preserving dependencies and lossless join."
  puts "b) Decompose into BCNF preserving lossless join."
  puts "c) Decompose into 4NF preserving lossless join."
  puts "d) Nothing. Exit the program.\n\n"
  print "> "
  choice = gets.chomp
  if /\A[abcd]\Z/.match(choice)
    case choice
    when 'a'
      if !contains_multi
        tnf = synth_3nf(rel)    # Synthesize the original relation to 3NF & print the results
        puts "\nFinal set of relations in 3NF\nPreserving Dependencies & Lossless Join:\n\n"
        i = 1
        tnf.each do |r|
          puts "R" + i.to_s
          r.print
          i += 1
        end
      else
        puts "\nThe relation contains an MVD, so the it can only be decomposed to 4NF."
      end
    when 'b'
      if !contains_multi
        bcnf = synth_bcnf(rel)  # Synthesize the original relation to BCNF & print the results
        puts "\nFinal set of relations in BCNF\nPreserving Lossless Join:\n\n"
        i = 1
        bcnf[0].each do |r|
          puts "R" + i.to_s
          r.print
          i += 1
        end
        
        puts "\nFDs lost during the BCNF Synthesis:\n\n"
        bcnf[1].each do |fd|
            fd.print
            puts ""
        end
      else
        puts "\nThe relation contains an MVD, so the it can only be decomposed to 4NF."
      end
    when 'c'
      fnf = synth_4nf(rel)  # Synthesize the original relation to 4NF & print the results
      puts "\nFinal set of relations in 4NF\nPreserving Lossless Join:\n\n"
        i = 1
        fnf[0].each do |r|
          puts "R" + i.to_s
          r.print
          i += 1
        end
          
      puts "\nFDs lost during the 4NF Synthesis:\n\n"
      fnf[1].each do |fd|
          fd.print
          puts ""
      end
    when 'd'
      exit
    end
  else
    puts "\nInvalid input!"
  end
end

