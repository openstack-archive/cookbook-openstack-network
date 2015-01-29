# encoding: UTF-8
#

# Library:: utils
module ::Utils
  def recipe_included?(recipe)
    if node['recipes'].include?(recipe)
      return true
    else
      return false
    end
  end
end
