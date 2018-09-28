using Electron

app = Application();
w = Window(app);

# function handle(message)
#     @info message["cmd"]
# end

# @async begin
#     while true
#         m = read(w)
#         println(m)
#     end
# end

@async for msg in msgchannel(w)
    @info msg
end

Electron.set_msg_handler(handle,w)

# run(w, "const {ipcRenderer} = require('electron')") //done for me already
# run(w, "ipcRenderer.send('msg-for-julia-process', {cmd: 'message for Julia'})") //done for me already
run(w, "sendMessageToJulia({cmd: 'message for Julia'})")

read(w) #to get the message
