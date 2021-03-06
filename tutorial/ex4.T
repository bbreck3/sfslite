// -*-c++-*-
/* $Id$ */

#include "tame.h"
#include "arpc.h"
#include "parseopt.h"
#include "ex_prot.h"

tamed static void 
dostuff (const str &h, int port, cbb cb)
{
  // declare all of your "stack" variables here
  tvars {
    int fd (99999);
    ptr<axprt_stream> x;
    ptr<aclnt> cli;
    vec<int> res;
    vec<clnt_stat> errs;
    int ntot (40), window_sz (5), id;
    int nsent (0), nrecv (0);
    bool err (false);
    rendezvous_t<int> rv;
  }

  // Call tcpconnect, and block until it returns; when it does return,
  // assign the local variable 'fd' to the result.
  twait { tcpconnect (h, port, mkevent(fd)); }


  if (fd < 0) {
    warn ("%s:%d: connection failed: %m\n", h.cstr(), port);
    err = true;
  } else {
    res.setsize (ntot);
    errs.setsize (ntot);
    x = axprt_stream::alloc (fd);
    cli = aclnt::alloc (x, ex_prog_1);

    // Now do the pipelined/windowed RPCs
    while (nrecv < ntot) {
      if (nsent < ntot && nsent - nrecv < window_sz) {
	// Launch new calls since there is room in the window!
	cli->call (EX_RANDOM, NULL, &res[nsent], 
		   mkevent (rv, nsent, errs[nsent])); 
	nsent++;
      } else {
	// Harvest
	twait (rv, id);
	if (errs[id]) {
	  err = true;
	  warn << "RPC error: " << errs[id] << "\n";
	} else {
	  warn << "Success " << id << ": " << res[id] << "\n";
	}
	nrecv++;
      }
    }
    warn << "All done...\n";
  }
  (*cb) (!err);
}

static void finish (bool rc)
{
  exit (rc ? 0 : -1);
}

static void play_with_rpc_vectors ()
{
  my_vec_t v1, v2;
  vec<u_int32_t> v3;
  v1.push_back (3); v1.push_back (4);
  v2.push_back (100);
  v3.push_back (1000);
  v1 += v2;
  v1 += v3;
}

int
main (int argc, char *argv[])
{
  int port;
  if (argc != 3 || !convertint (argv[2], &port))
    fatal << "usage: ex2 <hostname> <port>\n";
  
  play_with_rpc_vectors ();
  dostuff (argv[1], port, wrap (finish));
  amain ();
}
