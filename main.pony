use "http"
use "files"
use "net_ssl"

primitive BaseUrl fun apply(): String => "https://api.twitch.tv/kraken"

actor Main
    new create(env: Env) =>
        let url = try
            URL.valid(BaseUrl() + "/users")?
        else
            env.exitcode(1)
            return
        end

        _Get(env, url)

actor _Get
    let _env: Env

    new create(env: Env, url: URL) =>
        _env = env
        let sslctl = try
            recover
                SSLContext
                    .>set_client_verify(true)
                    .>set_authority(FilePath(env.root as AmbientAuth, "cacert.pem")?)?
            end
        end

        try
            let client = HTTPClient(env.root as AmbientAuth, consume sslctl)
            let dumpMaker = recover val NotifyFactory(this) end
            let req = Payload.request("GET", url)
            req("User-Agent") = "Pony httpget"
            req("Accept") = "application/vnd.twitchtv.v5+json"
            req("Client-ID") = ""

            let sentreq = client(consume req, dumpMaker)?
        else
            env.exitcode(1)
        end

    be receive(response: Payload val) =>
        _env.out.print(response.status.string())

        try
            for b in response.body()?.values() do
                _env.out.print(b)
            end
        end

class NotifyFactory is HandlerFactory
    let _get: _Get

    new create(get: _Get) =>
        _get = get

    fun apply(session: HTTPSession): HTTPHandler ref^ =>
        HttpNotify(_get, session)

class HttpNotify is HTTPHandler
    let _get: _Get
    let _session: HTTPSession

    new create(get: _Get, session: HTTPSession) =>
        _session = session
        _get = get

    fun apply(response: Payload val) =>
        _get.receive(response)

    fun finished() =>
        _session.dispose()
