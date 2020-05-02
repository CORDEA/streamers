use "http"
use "files"
use "net_ssl"

actor Main
    new create(env: Env) =>
        let url = try
            URL.valid("")?
        else
            env.exitcode(1)
            return
        end

        _Get(env, url)

actor _Get
    new create(env: Env, url: URL) =>
        let sslctl = try
            recover
                SSLContext
                    .>set_client_verify(true)
                    .>set_authority(FilePath(env.root as AmbientAuth, "cacert.pem")?)?
            end
        end

        try
            let client = HTTPClient(env.root as AmbientAuth, consume sslctl)
            let dumpMaker = recover val NotifyFactory.create() end
            // TODO
            /* let sentreq = client(consume req, dumpMaker)? */
        else
            env.exitcode(1)
        end

class NotifyFactory is HandlerFactory
    fun apply(session: HTTPSession): HTTPHandler ref^ =>
        HttpNotify(session)

class HttpNotify is HTTPHandler
    let _session: HTTPSession

    new create(session: HTTPSession) =>
        _session = session

    fun finished() =>
        _session.dispose()
