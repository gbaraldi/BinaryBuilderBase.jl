using Test
using BinaryBuilderBase: extract_kwargs, extract_fields, strip_path_separator, ArchiveSource, stdlib_version
using Downloads: RequestError
using UUIDs: UUID

@testset "Compat functions" begin
    foo(; kwargs...) = collect(extract_kwargs(kwargs, (:bar, :qux)))
    @test foo(; a = 1) == Pair[]
    @test foo(; bar = 2, b = 3) == [:bar => 2]
    @test foo(; c = 4, qux = 5) == [:qux => 5]
    @test Set(foo(; qux = 6, d = 7, bar = 8)) == Set([:bar => 8, :qux => 6])

    @test extract_fields(ArchiveSource("http://example.org", "this is the hash"; unpack_target = "target")) == Dict("url" => "http://example.org", "hash" => "this is the hash", "unpack_target" => "target")

    @test strip_path_separator("/home/wizard") == "/home/wizard"
    @test strip_path_separator("/home/wizard/") == "/home/wizard"
    @test strip_path_separator("/home//wizard///") == "/home//wizard"
    @test strip_path_separator("wizard.jl") == "wizard.jl"
    # Test integration with `basename`
    @test basename(strip_path_separator("/home/wizard")) == "wizard"
    @test basename(strip_path_separator("/home/wizard/")) == "wizard"
    @test basename(strip_path_separator("/home//wizard///")) == "wizard"
    @test basename(strip_path_separator("wizard.jl")) == "wizard.jl"

    gmp_jll = UUID("781609d7-10c4-51f6-84f2-b8444358ff6d")
    llvmlibwnwind_jll = UUID("47c5dbc3-30ba-59ef-96a6-123e260183d9")
    @test stdlib_version(gmp_jll, v"1.6") == v"6.2.0+5"
    @test stdlib_version(llvmlibwnwind_jll, v"1.6") === nothing
    if VERSION ≥ v"1.7-DEV"
        # Fascinating, different versions of Julia have different opinions about GMP_jll in v1.7
        if VERSION ≥ v"1.8-DEV"
            @test stdlib_version(gmp_jll, v"1.7") == v"6.2.1+1"
            # Pkg in Julia v1.8.1 believes that GMP_jll was retroactively
            # downgraded: https://github.com/JuliaLang/Pkg.jl/issues/3203
            if VERSION == v"1.8.1"
                @test stdlib_version(gmp_jll, v"1.8") == v"6.2.1+1"
            else
                @test stdlib_version(gmp_jll, v"1.8") == v"6.2.1+2"
            end
            @test stdlib_version(llvmlibwnwind_jll, v"1.8") == v"12.0.1+0"
        else
            @test stdlib_version(gmp_jll, v"1.7") == v"6.2.1+0"
            @test stdlib_version(llvmlibwnwind_jll, v"1.7") == v"11.0.1+1"
        end
    end
end

using BinaryBuilderBase: download_verify, list_tarball_files
@testset "ArchiveUtils" begin
    mktempdir() do dir
        # Test that we can download, then list, the contents of .tar.gz, .tar.bz2 and .tar.xz files.
        for (url, hash) in [("https://github.com/staticfloat/small_bin/raw/master/socrates.tar.gz",
                             "e65d2f13f2085f2c279830e863292312a72930fee5ba3c792b14c33ce5c5cc58"),
                            ("https://github.com/staticfloat/small_bin/raw/master/socrates.tar.xz",
                             "61bcf109fcb749ee7b6a570a6057602c08c836b6f81091eab7aa5f5870ec6475"),
                            ("https://github.com/staticfloat/small_bin/raw/master/socrates.tar.bz2",
                             "13fc17b97be41763b02cbb80e9d048302cec3bd3d446c2ed6e8210bddcd3ac76")]
            # First, download to a path:
            path = joinpath(dir, basename(url))
            @test_logs (:info, "Downloading $(url) to $(path)...") download_verify(url, hash, path)
            @test isfile(path)

            # Ensure that we can list the tarball:
            @test "bin/socrates" in list_tarball_files(path)
        end

        # Test that a 404 throws
        url = "https://github.com/not_a_file"
        dest = joinpath(dir, "blah")
        @test_logs (:info, "Downloading $(url) to $(dest)...") @test_throws RequestError download_verify(url, "0"^64, dest)

        # Test that a bad hash logs a message and fails
        url = "https://github.com/staticfloat/small_bin/raw/master/socrates.tar.xz"
        dest = joinpath(dir, "blah2")
        @test_logs (:error, r"Hash Mismatch") (:info, "Downloading $(url) to $(dest)...") match_mode=:any @test_throws ErrorException begin
            download_verify(url, "0"^64, dest)
        end
    end
end
