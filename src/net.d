/*
Copyright (c) 2025 tspike2k@github.com
Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_BOOST.txt or copy at http://www.boost.org/LICENSE_1_0.txt
*/

// TODO: Better logging!

import memory;
import logging;

enum Socket_Status : uint {
    Closed     = 0,
    Opened     = 1,
    Listening  = 2,
    Connecting = 3,
    Connected  = 4,
}

enum{
    Socket_Flag_TCP       = (1 << 0),
    Socket_Flag_Host      = (1 << 1),
    Socket_Flag_Broadcast = (1 << 2),
}

enum{
    Socket_Event_Readable = (1 << 0),
    Socket_Event_Writable = (1 << 1),
}

version(linux){
    import core.sys.posix.sys.types;
    import core.sys.posix.sys.socket;
    import core.sys.posix.netinet.in_;
    import core.sys.posix.netinet.tcp;
    import core.sys.posix.netdb;
    import core.sys.posix.arpa.inet;
    import core.sys.posix.fcntl;
    import core.sys.posix.unistd;
    import core.sys.posix.poll;

    enum SOCK_NONBLOCK = 2048; // For some reason, this isn't define by the standard D bindings.

    struct Socket{
        Socket_Status status;
        uint          events;
        uint          flags;
        bool          is_host;

        private:
        int fd;
    }

    /*
    private void get_socket_address_string(Socket* sock, char* buffer, uint buffer_length){
        assert(buffer_length >= INET6_ADDRSTRLEN);
        assert(sock.address_info);
        addrinfo *info = sock.address_info;
        inet_ntop(info.ai_family, &(cast(sockaddr_in*)info.ai_addr).sin_addr, buffer, buffer_length);
    }*/

    bool open_socket(Socket* sock, String address, String port, uint flags){
        assert(sock.status == Socket_Status.Closed);

        bool success = false;
        bool is_host = cast(bool)(flags & Socket_Flag_Host);

        sock.fd = -1;
        sock.events = 0;
        sock.flags = flags;

        auto hints = zero_type!addrinfo;

        if(flags | Socket_Flag_Broadcast){
            hints.ai_family = AF_INET;
        }
        else{
            hints.ai_family = AF_UNSPEC; // TODO: Is this needed for the client to work properly?
        }

        if(flags & Socket_Flag_TCP)
            hints.ai_socktype = SOCK_STREAM;
        else
            hints.ai_socktype = SOCK_DGRAM;

        if(is_host && address.length == 0)
            hints.ai_flags    = AI_PASSIVE;

        addrinfo* info;
        int e = getaddrinfo(address.ptr, port.ptr, &hints, &info);
        if(e == 0){
            assert(info); // TODO: Is this always non-null when getaddrinfo returns 0?
            scope(exit) freeaddrinfo(info);

            // TODO: We should probably loop through each res node looking for the best fit.
            // However, I'm not sure how we'd know what would be best.
            sock.fd = socket(info.ai_family, info.ai_socktype | SOCK_NONBLOCK, info.ai_protocol);
            if(sock.fd != -1){
                // TODO: Error out if we can't configure the socket the way we want.
                success = true;

                if(is_host){
                    int value = 1;
                    // Allow the host to reclaim socket number quickly when reconnecting.
                    if(setsockopt(sock.fd, SOL_SOCKET, SO_REUSEADDR, &value, value.sizeof) == -1){
                        log_error("Unable to set socket to reuse addresses.\n");
                    }

                    if(flags & Socket_Flag_Broadcast){
                        setsockopt(sock.fd, SOL_SOCKET, SO_BROADCAST, &value, value.sizeof);
                    }

                    // Prepare the host sock to listen
                    // Associate the address information filled out above with the socket file descriptor opened earlier.
                    if(bind(sock.fd, info.ai_addr, info.ai_addrlen) == 0){
                        sock.status = Socket_Status.Listening;

                        // 5 is the typical maximum size of the backlog queue
                        // TODO: Is that even true? Can we get the maximum like in Windows?
                        listen(sock.fd, 5); // TODO: Can listen fail?
                        log("Created host socket\n"); // TODO: Print host IP address and port number.
                    }
                    else{
                        log_error("Unable to bind socket fd. Aborting\n");
                        success = false;
                    }
                }
                else{
                    // TODO: Set these up?
                    int value = 1;
                    /*setsockopt(socket_fd, SOL_SOCKET, SO_DONTLINGER, NULL, 0);*/
                    if(flags & Socket_Flag_TCP){
                        setsockopt(sock.fd, IPPROTO_TCP, TCP_NODELAY, &value, value.sizeof);
                    }

                    sock.status = Socket_Status.Opened;
                }
            }
            else{
                //log_error("Unable to open socket at address %s:%s\n", address, port);
                log_error("Unable to open socket at address ");
                log(address);
                log(":");
                log(port);
                log("\n");
            }
        }
        else{
            //log_error("Unable to get host address information: %s\n", gai_strerror(e));
            log_error("Unable to get host address information\n");
        }

        if(!success){
            close_socket(sock);
        }

        return success;
    }

    void close_socket(Socket* sock){
        if(sock.fd != -1){
            close(sock.fd);
            sock.fd     = -1;
            sock.status = Socket_Status.Closed;
            sock.events = 0;
        }
    }

    void sockets_poll(Socket[] sockets, Allocator* allocator){
        push_frame(allocator.scratch);
        scope(exit) pop_frame(allocator.scratch);

        auto poll_fds = alloc_array!pollfd(allocator, sockets.length);
        foreach(i, ref entry; poll_fds){
            entry.fd = sockets[i].fd;
            entry.revents = POLLIN|POLLOUT;
        }

        poll(&poll_fds[0], poll_fds.length, 0);

        foreach(i, ref socket; sockets){
            socket.events = 0;

            auto events = poll_fds[i].revents;
            if(events & POLLIN){
                socket.events |= Socket_Event_Readable;
            }
            if(events & POLLOUT){
                socket.events |= Socket_Event_Writable;
            }
        }
    }
}
