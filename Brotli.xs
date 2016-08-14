#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <dec/decode.h>
#include <common/dictionary.h>

#define BUFFER_SIZE 1048576

MODULE = IO::Compress::Brotli		PACKAGE = IO::Uncompress::Brotli
PROTOTYPES: ENABLE

SV* unbro(buffer)
    SV* buffer
  PREINIT:
    size_t decoded_size;
    STRLEN encoded_size;
    uint8_t *encoded_buffer, *decoded_buffer;
  CODE:
    encoded_buffer = (uint8_t*) SvPV(buffer, encoded_size);
    if(!BrotliDecompressedSize(encoded_size, encoded_buffer, &decoded_size)){
        croak("Error in BrotliDecompressedSize");
    }
    Newx(decoded_buffer, decoded_size+1, uint8_t);
    decoded_buffer[decoded_size]=0;
    if(!BrotliDecoderDecompress(encoded_size, encoded_buffer, &decoded_size, decoded_buffer)){
        croak("Error in BrotliDecoderDecompress");
    }
    RETVAL = newSV(0);
    sv_usepvn_flags(RETVAL, decoded_buffer, decoded_size, SV_HAS_TRAILING_NUL);
  OUTPUT:
    RETVAL

SV* BrotliDecoderCreateInstance()
  CODE:
    RETVAL = newSViv((IV)BrotliDecoderCreateInstance(NULL, NULL, NULL));
  OUTPUT:
    RETVAL

void BrotliDecoderDestroyInstance(state)
    SV* state
  CODE:
    BrotliDecoderDestroyInstance((BrotliDecoderState*)SvIV(state));

SV* BrotliDecoderDecompressStream(state, in)
    SV* state
    SV* in
  PREINIT:
    uint8_t *next_in, *next_out, *buffer;
    size_t available_in, available_out;
    BrotliDecoderResult result;
  CODE:
    next_in = (uint8_t*) SvPV(in, available_in);
    Newx(buffer, BUFFER_SIZE, uint8_t);
    RETVAL = newSVpv("", 0);
    result = BROTLI_RESULT_NEEDS_MORE_OUTPUT;
    while(result == BROTLI_RESULT_NEEDS_MORE_OUTPUT) {
        next_out = buffer;
        available_out=BUFFER_SIZE;
        result = BrotliDecoderDecompressStream( (BrotliDecoderState*) SvIV(state),
                                                &available_in,
                                                (const uint8_t**) &next_in,
                                                &available_out,
                                                &next_out,
                                                NULL );
        if(!result){
            Safefree(buffer);
            croak("Error in BrotliDecoderDecompressStream");
        }
        sv_catpvn(RETVAL, (const char*)buffer, BUFFER_SIZE-available_out);
    }
    Safefree(buffer);
  OUTPUT:
    RETVAL

void BrotliDecoderSetCustomDictionary(state, dict)
    SV* state
    SV* dict
  PREINIT:
    size_t size;
    uint8_t *data;
  CODE:
    data = SvPV(dict, size);
    BrotliDecoderSetCustomDictionary((BrotliDecoderState*) SvIV(state), size, data);
