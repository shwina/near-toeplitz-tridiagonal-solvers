#include <stdio.h>
__global__ void sharedMemCyclicReduction( double *a_d,
                                double *b_d,
                                double *c_d,
                                double *d_d,
                                double *k1_d,
                                double *k2_d,
                                double *b_first_d,
                                double *k1_first_d,
                                double *k1_last_d,
                                const double b1,
                                const double c1,
                                const double ai,
                                const double bi,
                                const double ci,
                                int nx,
                                int ny,
                                int nz) {
    /*

    */
    __shared__ double d_l[128];

    int ix = blockIdx.x*blockDim.x + threadIdx.x; 
    int iy = blockIdx.y*blockDim.y + threadIdx.y; 
    int iz = blockIdx.z*blockDim.z + threadIdx.z; 
    int tix = threadIdx.x; 
    int i, m, n;
    int idx, stride;
    int line_start = iz*(nx*ny) + iy*nx + 0;
    double k1, k2;
    double d_m, d_n;

    /* When loading to shared memory, perform the first
       reduction step */
    idx = 0;
    if (tix == 0) {
        d_l[tix] = d_d[line_start+2*tix+1] - \
                    d_d[line_start+2*tix]*k1_first_d[idx] - \
                    d_d[line_start+2*tix+2]*k2_d[idx];
    }
    else if (tix == (nx/2-1)) {
        d_l[tix] = d_d[line_start+2*tix+1] - \
                     d_d[line_start+2*tix]*k1_last_d[idx];
    }
    else {
        d_l[tix] = d_d[line_start+2*tix+1] - d_d[line_start+2*tix]*k1_d[idx] - \
                    d_d[line_start+2*tix+2]*k2_d[idx];
    }
    __syncthreads();
    
    /* First step of reduction is complete and 
       the coefficients are in shared memory */
    
    /* Do the remaining forward reduction steps: */
    stride = 1;
    for (int step=0; step<rint(log2((float) nx/4)); step++) {
        stride = stride*2;
        idx = idx + 1;
        if (tix < nx/(2*stride)) {
            i = (stride-1) + tix*stride;
            if (tix == 0) {
                d_l[i] = d_l[i] - \
                            d_l[i-stride/2]*k1_first_d[idx] - \
                            d_l[i+stride/2]*k2_d[idx];
            }
            else if (i == (nx/2-1)) {
                d_l[i] = d_l[i] - \
                             d_l[i-stride/2]*k1_last_d[idx];
            }
            else {
                d_l[i] = d_l[i] - d_l[i-stride/2]*k1_d[idx] - \
                            d_l[i+stride/2]*k2_d[idx];
            }
        }
        __syncthreads();
    }

    if (tix == 0) {
        m = rint(log2((float) nx/2)) - 1;
        n = rint(log2((float) nx/2));

        d_m = (d_l[nx/4-1]*b_d[n] - \
               c_d[m]*d_l[nx/2-1])/ \
            (b_first_d[m]*b_d[n] - c_d[m]*a_d[n]);

        d_n = (b_first_d[m]*d_l[nx/2-1] - \
               d_l[nx/4-1]*a_d[n])/ \
            (b_first_d[m]*b_d[n] - c_d[m]*a_d[n]);

        d_l[nx/4-1] = d_m;
        d_l[nx/2-1] = d_n;
    }
    __syncthreads();

    stride = nx/2;    
     
    idx = rint(log2((float) nx))-2;
    for (int step=0; step<rint(log2((float) nx))-2; step++) {
        stride = stride/2;
        idx = idx - 1;
        if (tix < nx/(2*stride)){
            i = (stride/2-1) + tix*stride;
            if (tix == 0) {
                d_l[i] = (d_l[i] - c_d[idx]*d_l[i+stride/2])/\
                            b_first_d[idx];
            }
            else {
                d_l[i] = (d_l[i] - a_d[idx]*d_l[i-stride/2] -\
                            c_d[idx]*d_l[i+stride/2])/b_d[idx];
            }
        }
        __syncthreads();
    }
    
    //When writing from shared memory, perform the last
    //substitution step
    if (tix == 0) {
        d_d[line_start+2*tix] = (d_d[line_start+2*tix] - c1*d_l[tix])/b1;
        d_d[line_start+2*tix+1] = d_l[tix];
    }
    else {
        d_d[line_start+2*tix] = (d_d[line_start+2*tix] - ai*d_l[tix-1] - ci*d_l[tix])/bi;
        d_d[line_start+2*tix+1] = d_l[tix];
    } 
    
    __syncthreads();
}

