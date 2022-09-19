@testitem "Tools" begin
    using Logging

    import Mimi:
        getproperty, pretty_string, set_log_level, log_debug, log_info

    #utils: pretty_string
    @test pretty_string("camelCaseBasic") == pretty_string(:camelCaseBasic) == "Camel Case Basic"
    @test pretty_string("camelWithAOneLetterWord") == pretty_string(:camelWithAOneLetterWord) == "Camel With A One Letter Word"
    @test pretty_string("snake_case_basic") == pretty_string(:snake_case_basic) == "Snake Case Basic"
    @test pretty_string("_snake__case__weird_") == pretty_string(:_snake__case__weird_) == "Snake Case Weird"

    #utils: interpolate
    stepsize = 2       
    final = 10         
    ts = 10
    @test Mimi.interpolate(collect(0:stepsize:final), ts) == collect(0:stepsize/ts:final)

    # utils: logging - toggle back and forth 
    log_debug()
    @test current_logger().min_level == Logging.Debug
    log_info()
    @test current_logger().min_level == Logging.Info

end
