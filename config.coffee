
coffeeGlob = ['src/**/*.', './*.']
module.exports =
    coffeeSrc: coffeeGlob.map (glob) ->
        glob + 'coffee'
    litcoffeeSrc: coffeeGlob.map (glob) ->
        glob + 'litcoffee'
    coffeeDst: 'build'
