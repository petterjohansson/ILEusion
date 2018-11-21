int str_2_packed(char * where, char *str, int tdim, int tlen, int tscale) {
  int i = 0;
  int j = 0;
  int k = 0;
  int outDigits = tlen;
  int outDecimalPlaces = tscale;
  int outLength = outDigits/2+1;
  int inLength = 0;
  int sign = 0;
  char chr[256];
  char dec[256];
  char * c;
  int leadingZeros = 0;
  int firstNibble = 0;
  int secondNibble = 0;
  char * wherev = where;

  /* fix up input */
  c = chr;
  inLength = ile_pgm_str_fix_decimal(str, tlen, tscale, c, sizeof(chr), &sign);

  /* convert string to packed */
  if (outDigits % 2 == 0) {
   leadingZeros = outDigits - inLength + 1;
  } else {
   leadingZeros = outDigits - inLength;
  }
  /* write correct number of leading zero's */
  for (i=0; i<leadingZeros-1; i+=2) {
    dec[j++] = 0;
  }
  if (leadingZeros > 0) {
    if (leadingZeros % 2 != 0) {
      dec[j++] = (char)(c[k++] & 0x000F);
    }
  }
  /* place all the digits except last one */
  while (j < outLength-1) {
    firstNibble = (char)(c[k++] & 0x000F) << 4;
    secondNibble = (char)(c[k++] & 0x000F);
    dec[j++] = (char)(firstNibble + secondNibble);
  }
  /* place last digit and sign nibble */
  firstNibble = (char)(c[k++] & 0x000F) << 4;
  if (!sign) {
    dec[j++] = (char)(firstNibble + 0x000F);
  }
  else {
    dec[j++] = (char)(firstNibble + 0x000D);
  }
  /* copy in */
  for (i=0; i < tdim; i++, wherev += outLength) {
    memcpy(wherev, dec, outLength);
  }
  return 0;
}

int ile_pgm_str_fix_decimal(char *str, int tlen, int tscale, char * buf, int len, int *sign) {
  int i = 0;
  int j = 0;
  char chr[256];
  char * a;
  char * c;
  int mint = 0;
  int aint = 0;
  int adot = 0;
  int mscale = 0;
  int ascale = 0;
  int inLength = 0;
  int trimLength = 0;
  int overflow = 0;

  /* zero user buffer */
  memset(buf,0,len);
  /* character zero buffer correct length (user) */
  memset(buf,'0',tlen);

  /* parse input string */
  c = str;
  inLength = strlen(c);
  if (inLength) {
    memset(chr,0,sizeof(chr));
    for (i=0, j=0; i < inLength; i++) {
      if (c[i] == '-') {
        *sign = 1;
      } else {
        if (ile_pgm_isnum_digit(c[i])) {
          chr[j++] = c[i];
          if (adot) {
            ascale++;
          } else {
            aint++;
          }
        }
      }
      if (!adot && c[i] == '.') {
          adot = 1;
      }
    }
    /* max char int (front) */
    if (tlen > tscale) {
      mint = tlen - tscale;
    }
    /* max char scale (back) */
    if (tscale) {
      mscale = tscale;
    }
    /* round scale (back) */
    if (ascale > mscale) {
      overflow = ile_pgm_str_fix_round(chr, strlen(chr), mscale);
    }
    /* copy out */
    a = chr;
    c = buf;
    /* integer too large (trunc front) */
    if (aint > mint) {
      i = 0;
      j = aint - mint;
      aint = mint;
    /* integer ok (front) */
    } else {
      i = mint - aint;
      j = 0;
    }
    for (ascale=0; i < tlen; i++) {
      if (aint) {
        c[i] = a[j++];
        aint--;
      } else {
        /* trunc scale (back) */
        if (ascale < mscale) {
          c[i] = a[j++];
        }
        ascale++;
      }
    }
  } /* inLength */
 
  return tlen;
}

int ile_pgm_isnum_digit(char c) {
  if (c >= '0' && c <= '9') {
    return 1;
  }
  return 0;
}

int ile_pgm_str_fix_round(char *str, int tlen, int tscale) {
  int i = 0;
  int overflow = 0;
  char * c = str;

  for (i=tlen-1;i && tscale;i--) {
    if (overflow || i == tlen-tscale) {
      if (overflow) {
        overflow = 0;
        switch(c[i-1]) {
        case '0':
          c[i-1] = '1';
          break;
        case '2':
          c[i-1] = '2';
          break;
        case '3':
          c[i-1] = '3';
          break;
        case '4':
          c[i-1] = '5';
          break;
        case '5':
          c[i-1] = '6';
          break;
        case '6':
          c[i-1] = '7';
          break;
        case '7':
          c[i-1] = '8';
          break;
        case '8':
          c[i-1] = '9';
          break;
        case '9':
          c[i-1] = '0';
          overflow = 1;
          if (tscale && i == tlen-tscale) {
            tscale--;
          }
          break;
        }
      }
    } else { 
      if (i > tlen-tscale && (c[i] > '5' && c[i-1] >= '5')) {
        c[i] = '0';
        switch(c[i-1]) {
        case '5':
          c[i-1] = '6';
          break;
        case '6':
          c[i-1] = '7';
          break;
        case '7':
          c[i-1] = '8';
          break;
        case '8':
          c[i-1] = '9';
          break;
        case '9':
          c[i-1] = '0';
          overflow = 1;
          if (tscale && i == tlen-tscale) {
            tscale--;
          }
          break;
        }
      }
    }
    if (tscale < 1 || i == tlen-tscale) {
      break;
    }
  }
  return overflow;
}