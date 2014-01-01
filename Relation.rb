
# Code by: Matt Antonelli

class Relation
  
  attr_reader :u, :f, :key
  
  def initialize(fds)
    @f = fds
    empty_check = fds.to_a[0]
    if empty_check.y.include?('0')
      @u = empty_check.x
      @key = @u
    else
      find_u
    end
  end
  
  def clone # Returns a deep copy of the relation
    f_clone = Set.new
    @f.each do |fd|
      f_clone.add(fd.clone)
    end
    return Relation.new(f_clone)
  end
  
  def find_key  # Find the key of the relation
    key = Set.new.merge(@u)
    @u.each do |att|
      key.delete(att)
      if !@u.subset?( find_xclosure(key, @f) )
        key.add(att)
      end
    end
    @key = key
  end
  
  def find_u  # Create the set of all attributes, U
    all_att = Set.new 
    f.each do |fd|
      fd.x.each do |x|
       all_att.add(x)
      end
      fd.y.each do |y|
        if y != '0' 
          all_att.add(y)
        end
      end
    end
    @u = all_att
    find_key
  end
  
  def remove_att(fd, att) # Remove a specific attribute form the relation
    new_fds = Set.new
    @f.each do |x|
      x = x.clone
      if !x.eql?(fd)
        if x.remove_att(att)
          new_fds.add(FD.new(x.x.merge(x.y) - att, (Set.new ['0']), false))
        else
          new_fds.add(x)
        end
      end
    end
    return new_fds
  end
  
  def set_f(f)  # Sets a new set of FDs for the relation and recalculates U
    @f.clear
    @u.clear
    @f.merge(f)
    find_u
  end
  
  def print # Prints the relation
    $stdout.print "( U: { "
    @u.each do |att|
      $stdout.print att
    end
    $stdout.print " } F: { "
    fds = @f.to_a
    for i in 0...fds.size
      fds[i].print
      if i != fds.size - 1
        $stdout.print ", "
      end
    end
    $stdout.print " } )\n"
=begin  Prints the key - not required for the project
    $stdout.print "} K: { "
    @key.each do |att|
      $stdout.print att
    end
    $stdout.print " } )\n"
=end
  end
end