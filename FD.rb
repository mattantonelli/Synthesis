
# Code by: Matt Antonelli

class FD
  
  attr_reader :x, :y, :multi
  
  def initialize(x, y, multi)
    @x = x
    if y == nil
      @y = Set.new ['0']
    else
      @y = y
    end
    @multi = multi
  end
  
  def clone # Returns a deep copy of the FD
    return FD.new(@x.dup, @y.dup, @multi)
  end
  
  def eql?(fd)  # Checks whether the FD is equal to the given FD
    return @x == fd.x && @y == fd.y && @multi == fd.multi
  end
  
  def hash  # Overrides the hash for comparing FDs in Sets
    [@x, @y, @multi].hash
  end

  def print # Prints the FD
    @x.each do |x|
      $stdout.print x
    end
    
    if @multi
      $stdout.print " ->> "
    else
      $stdout.print " --> "
    end
    
    @y.each do |y|
      $stdout.print y
    end
  end

  def remove_att(att) # Removes a specific attribute from the FD
    if (@x & att).size > 0
      return true # Return true => FD should be removed
    end
    @y.subtract(att)
    if @y.size == 0
      @y = Set.new ['0']
    end
    hash
    return false  # Return false => FD should not be removed
  end
  
  def remove_x(att) # Removes a specific attribute from the FD's determinant only
    @x.delete(att)
  end
  
  def set_multi(multi)  # Sets whether or not the FD is an MVD
    @multi = multi
  end

end