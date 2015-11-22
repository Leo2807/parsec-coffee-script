gulp = require 'gulp'
gulpCoffee = require 'gulp-coffee'
gulpCoffeeLint = require 'gulp-coffeelint'
gulpUtil = require 'gulp-util'
gulpChanged = require 'gulp-changed'

config = require './config'

gulp.task 'coffee-watch', ->
    gulp.watch config.coffeeSrc, ['coffee']
    gulp.watch config.litcoffeeSrc, ['litcoffee']

genCoffeeTask = (literate) ->
    ->
        task = gulp.src(config.coffeeSrc)
            .pipe gulpChanged config.coffeeDst

        if gulpUtil.env.type == 'dev'
            task.pipe gulpCoffeeLint()
                .pipe gulpCoffeeLint.reporter('coffeelint-stylish')
                .pipe gulpCoffeeLint.reporter('fail')

        task.pipe(gulpCoffee(
            { bare: true, literate: literate }
        ).on 'error', gulpUtil.log)
            .pipe gulp.dest config.coffeeDst

gulp.task 'coffee', genCoffeeTask no
gulp.task 'litcoffee', genCoffeeTask yes
