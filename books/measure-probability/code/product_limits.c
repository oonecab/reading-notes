/* Exact kernel / Bernoulli masses. Standardized characteristic function uses double. */
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <stddef.h>

typedef unsigned long long U;
static int number(const char *s, unsigned limit, unsigned *out) {
    size_t len = strlen(s);
    unsigned v = 0;
    if (!len || len > 10) return 0;
    for (size_t i = 0; i < len; ++i) {
        if (s[i] < '0' || s[i] > '9') return 0;
        v = 10*v + (unsigned)(s[i]-'0');
        if (v > limit) return 0;
    }
    *out = v;
    return 1;
}
static void array(const U *v, unsigned count) {
    putchar('[');
    for (unsigned i = 0; i < count; ++i) printf("%s%llu", i ? "," : "", v[i]);
    putchar(']');
}
static void joint(unsigned p, unsigned a, unsigned b, unsigned m) {
    U w[4] = {(U)(m-p)*(m-a), (U)(m-p)*a, (U)p*(m-b), (U)p*b};
    U row[2] = {w[0]+w[1], w[2]+w[3]};
    U col[2] = {w[0]+w[2], w[1]+w[3]};
    U direct = 2*w[1]+w[2]+3*w[3];
    U iterated = (U)(m-p)*2*a+(U)p*((m-b)+3*b);
    printf("{\"mode\":\"joint\",\"denominator\":%llu,\"weights\":", (U)m*m);
    array(w, 4);
    printf(",\"row_weights\":"); array(row, 2);
    printf(",\"col_weights\":"); array(col, 2);
    printf(",\"expectation_numerator\":%llu,\"iterated_numerator\":%llu,\"independent\":%s}\n",
           direct, iterated, w[0]*w[3] == w[1]*w[2] ? "true" : "false");
}
static void binomial(unsigned n, unsigned p, unsigned m) {
    U w[17] = {1}, denominator = 1, mean_num = 0;
    for (unsigned j = 0; j < n; ++j) {
        U next[17] = {0};
        for (unsigned k = 0; k <= j; ++k) {
            next[k] += w[k]*(m-p);
            next[k+1] += w[k]*p;
        }
        memcpy(w, next, sizeof w);
        denominator *= m;
    }
    for (unsigned k = 0; k <= n; ++k) mean_num += k*w[k];
    U variance_num = (U)n*p*(m-p);
    printf("{\"mode\":\"binomial\",\"denominator\":%llu,\"weights\":", denominator);
    array(w, n+1);
    printf(",\"mean_numerator\":%llu,\"variance_numerator\":%llu,\"variance_denominator\":%llu,",
           mean_num, variance_num, (U)m*m);
    printf("\"normalizable\":%s,\"standardized_cf_t1\":", variance_num ? "true" : "false");
    if (variance_num) {
        double mean = (double)n*p/m, sd = sqrt((double)variance_num)/m;
        double real = 0, imaginary = 0;
        for (unsigned k = 0; k <= n; ++k) {
            double z = ((double)k-mean)/sd;
            real += (double)w[k]*cos(z);
            imaginary += (double)w[k]*sin(z);
        }
        printf("[%.17g,%.17g]", real/(double)denominator, imaginary/(double)denominator);
    } else printf("null");
    printf("}\n");
}
int main(int argc, char **argv) {
    unsigned p, a, b, m, n;
    if (argc == 6 && !strcmp(argv[1], "joint") && number(argv[2],1000,&p) &&
        number(argv[3],1000,&a) && number(argv[4],1000,&b) && number(argv[5],1000,&m) &&
        m && p <= m && a <= m && b <= m) {
        joint(p,a,b,m); return 0;
    }
    if (argc == 5 && !strcmp(argv[1], "binomial") && number(argv[2],16,&n) &&
        number(argv[3],8,&p) && number(argv[4],8,&m) && m && p <= m) {
        binomial(n,p,m); return 0;
    }
    fprintf(stderr,"usage: joint p a b m (m=1..1000) | binomial n p m (n=0..16,m=1..8); probabilities in [0,m]\n");
    return 2;
}
