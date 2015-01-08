# encoding: UTF-8
#

# Library:: utils
module ::Utils
  def recipe_included?(recipe)
    node['recipes'].include?(recipe)
  end

  def role_included?(role)
    node['roles'].include?(role)
  end
end
