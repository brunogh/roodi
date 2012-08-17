def swap(a, b)
  temp = b
  b = a
  a = temp
end

def swap2(a, b)
  a += b
  b = a - b
  a -= b
end
