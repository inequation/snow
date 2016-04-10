/**************************************************************************
**
**   SNOW - CS224 BROWN UNIVERSITY
**
**   tim.cu
**   Author: taparson
**   Created: 8 Apr 2014
**
**************************************************************************/

#ifndef TIM_CU
#define TIM_CU

#include <GL/glew.h>

#include <cuda.h>
#include <cuda_runtime.h>
#include <cuda_gl_interop.h>
#include <helper_cuda.h>
#include <helper_cuda_gl.h>

#ifndef GLM_FORCE_RADIANS
    #define GLM_FORCE_RADIANS
#endif
#include <glm/geometric.hpp>
#include <glm/vec3.hpp>
#include <glm/mat3x3.hpp>

#define CUDA_INCLUDE
#include "sim/particle.h"
#include "geometry/grid.h"
#include "cuda/functions.h"

extern "C"  {
void groupParticlesTests();
void cumulativeSumTests();
void CSTest1();
void CSTest2();
void CSTest3();
void CSTest4();
void CSTest5();
void PGTest1();

}



__host__ __device__ void gridIndexToIJK(int idx, int &i, int &j, int &k,const  glm::ivec3 &nodeDim){
    i = idx / (nodeDim.y*nodeDim.z);
    idx = idx % (nodeDim.y*nodeDim.z);
    j = idx / nodeDim.z;
    k = idx % nodeDim.z;
}

__host__ __device__ int getGridIndex( int i, int j, int k, const glm::ivec3 &nodeDim)  {
    return (i*(nodeDim.y*nodeDim.z) + j*(nodeDim.z) + k);
}

__host__ __device__ void gridIndexToIJK(int idx, const  glm::ivec3 &nodeDim, glm::ivec3 &IJK){
    gridIndexToIJK(idx, IJK.x, IJK.y, IJK.z, nodeDim);
}

__host__ __device__ int getGridIndex( const glm::ivec3 &IJK, const glm::ivec3 &nodeDim)  {
    return getGridIndex(IJK.x, IJK.y, IJK.z, nodeDim);
}



__host__ __device__ void positionToGridIJK(vec3 pos, Grid *grid, int &i, int &j, int &k){
    pos-=grid->pos;
    pos/=grid->h;
    pos = vec3::round(pos);
    i = (int) pos.x;
    j = (int) pos.y;
    k = (int) pos.z;
}

__host__ __device__ void positionToGridIJK(vec3 &pos, Grid *grid, glm::ivec3 &gridIJK){
    pos-=grid->pos;
    pos /= grid->h;
    pos = vec3::round(pos);
    gridIJK = glm::ivec3((int) pos.x, (int) pos.y, (int) pos.z);
}

/**
* Assuming N = # particles, M = dim.x*dim.y*dim.z for grid.
* naming convention: things that start with “particle” have N items, things that start with “cell” have M items.
* particleData: Array of type Particle, simply a list of all of our particles, size N
* grid: Grid dimensions and unit size
* particleToCell: Array of type int, size N, index of cell that particle belongs to.
* cellParticleCount: Array of type int, size M, number of particles in each cell.
* particleOffsetInCell: Array of type int, size N, offset for each particle into cell’s subarray. (number of particles already inserted into the cell that the particle belongs to)
*
*/
__global__ void rasterizeParticles( Particle *particleData, Grid *grid, int *particleToCell, int *cellParticleCount, int *particleOffsetInCell ) {
    int index = blockIdx.x*blockDim.x + threadIdx.x;
    Particle p = particleData[index];
    glm::ivec3 gridIJK;
    //positionToGridIJK(p.position, grid, gridIJK);
    int gridIndex = getGridIndex(gridIJK.x, gridIJK.y, gridIJK.z, grid->dim+1);
    particleToCell[index] = gridIndex;
    particleOffsetInCell[index]=cellParticleCount[gridIndex]++;
}

__global__ void cumulativeSum(int *array, int M)  {
    int sum = 0;
    for(int i = 0; i < M; i++)  {
        sum+=array[i];
        array[i] = sum;
    }
}

/**
 * particleToCell: Array of type int, size N, index of the cell that particle belongs to.
 * cellParticleIndex: Array of type int, size M, index of first particle for each cell
 * particleOffsetInCell: Array of type int, size N, offset for each particle into cell’s subarray
 * gridParticles: Array of type int, size N, particle indices group by ascending cell index
 */
__global__ void groupParticlesByCell( int *particleToCell, int *cellParticleIndex, int *particleOffsetInCell, int *gridParticles )  {
    int index = blockIdx.x*blockDim.x + threadIdx.x;
    int gridIndex = particleToCell[index];
    int subPosition = particleOffsetInCell[index];
    int resultIndex = cellParticleIndex[gridIndex] + subPosition;
    gridParticles[resultIndex] = index;
}

void groupParticlesTests()  {
    printf("running particle grouping tests...\n");

    PGTest1();

    printf("done running particle grouping tests\n");
}

void PGTest1()  {
    int particleToCell[8] = {2,3,2,1,0,7,6,5};
    int cellParticleIndex[9] = {0,1,1,2,1,0,1,1,1};
    int particleOffsetInCell[8] = {0,0,1,0,0,0,0,0};
    int gridParticles[8] = {0,0,0,0,0,0,0,0};
    int *dev_particleToCell, *dev_cellParticleIndex, *dev_particleOffsetInCell, *dev_gridParticles;
    checkCudaErrors(cudaMalloc((void**) &dev_particleToCell, 8*sizeof(int)));
    checkCudaErrors(cudaMemcpy(dev_particleToCell,particleToCell,8*sizeof(int),cudaMemcpyHostToDevice));
    checkCudaErrors(cudaMalloc((void**) &dev_cellParticleIndex, 9*sizeof(int)));
    checkCudaErrors(cudaMemcpy(dev_cellParticleIndex,cellParticleIndex,9*sizeof(int),cudaMemcpyHostToDevice));
    checkCudaErrors(cudaMalloc((void**) &dev_particleOffsetInCell, 8*sizeof(int)));
    checkCudaErrors(cudaMemcpy(dev_particleOffsetInCell,particleOffsetInCell,8*sizeof(int),cudaMemcpyHostToDevice));
    checkCudaErrors(cudaMalloc((void**) &dev_gridParticles, 8*sizeof(int)));
    checkCudaErrors(cudaMemcpy(dev_gridParticles,gridParticles,8*sizeof(int),cudaMemcpyHostToDevice));

    cumulativeSum<<<1,1>>>(dev_cellParticleIndex,9);
    cudaDeviceSynchronize();
    groupParticlesByCell<<<8,1>>>(dev_particleToCell,dev_cellParticleIndex,dev_particleOffsetInCell,dev_gridParticles);

    cudaDeviceSynchronize();
    cudaMemcpy(gridParticles,dev_gridParticles,8*sizeof(int),cudaMemcpyDeviceToHost);
    cudaFree(dev_particleToCell);
    cudaFree(dev_cellParticleIndex);
    cudaFree(dev_particleOffsetInCell);
    cudaFree(dev_gridParticles);
    printf("{");
    for (int i=0; i < 8; i++)  {
        printf("%d,",gridParticles[i]);
    }
    printf("}\n");
}

void cumulativeSumTests()
{
    printf("running cumulative sum tests...\n");
    CSTest1();
    CSTest2();
    CSTest3();
    CSTest4();
    CSTest5();
    printf("done running cumulative sum tests\n");
}

void CSTest1()  {
    int array[5] = {0,1,2,3,4};
    int expected[5] = {0,1,3,6,10};
    printf("running test on array: [%d,%d,%d,%d,%d]...\n",array[0],array[1],array[2],array[3],array[4]);
    int *dev_array;
    checkCudaErrors(cudaMalloc((void**) &dev_array, 5*sizeof(int)));
    checkCudaErrors(cudaMemcpy(dev_array,array,5*sizeof(int),cudaMemcpyHostToDevice));
    cumulativeSum<<<1,1>>>(dev_array,5);
    cudaMemcpy(array,dev_array,5*sizeof(int),cudaMemcpyDeviceToHost);
    cudaDeviceSynchronize();
    cudaFree(dev_array);
    for (int i = 0; i < 5; i++)  {
        if (array[i] != expected[i])  {
            printf("failed test %d",1);
            printf("expected array: {%d,%d,%d,%d,%d}",expected[0],expected[1],expected[2],expected[3],expected[4]);
            printf("    got: {%d,%d,%d,%d,%d}\n",array[0],array[1],array[2],array[3],array[4]);
            break;
        }
    }
}

void CSTest2()  {
    int array[5] = {5,1,2,3,4};
    int expected[5] = {5,6,8,11,15};
    printf("running test on array: [%d,%d,%d,%d,%d]...\n",array[0],array[1],array[2],array[3],array[4]);
    int *dev_array;
    checkCudaErrors(cudaMalloc((void**) &dev_array, 5*sizeof(int)));
    checkCudaErrors(cudaMemcpy(dev_array,array,5*sizeof(int),cudaMemcpyHostToDevice));
    cumulativeSum<<<1,1>>>(dev_array,5);
    cudaMemcpy(array,dev_array,5*sizeof(int),cudaMemcpyDeviceToHost);
    cudaDeviceSynchronize();
    cudaFree(dev_array);
    for (int i = 0; i < 5; i++)  {
        if (array[i] != expected[i])  {
            printf("failed test %d",1);
            printf("expected array: {%d,%d,%d,%d,%d}",expected[0],expected[1],expected[2],expected[3],expected[4]);
            printf("    got: {%d,%d,%d,%d,%d}\n",array[0],array[1],array[2],array[3],array[4]);
            break;
        }
    }
}

void CSTest3()  {
    int array[1] = {5};
    int expected[1] = {5};
    printf("running test on array: [%d]...\n",array[0]);
    int *dev_array;
    checkCudaErrors(cudaMalloc((void**) &dev_array, 1*sizeof(int)));
    checkCudaErrors(cudaMemcpy(dev_array,array,1*sizeof(int),cudaMemcpyHostToDevice));
    cumulativeSum<<<1,1>>>(dev_array,1);
    cudaMemcpy(array,dev_array,1*sizeof(int),cudaMemcpyDeviceToHost);
    cudaDeviceSynchronize();
    cudaFree(dev_array);
    for (int i = 0; i < 1; i++)  {
        if (array[i] != expected[i])  {
            printf("failed test %d",1);
            printf("expected array: {%d}",expected[0]);
            printf("    got: {%d}\n",array[0]);
            break;
        }
    }
}

void CSTest4()  {
    int array[1] = {0};
    int expected[1] = {0};
    printf("running test on array: [%d]...\n",array[0]);
    int *dev_array;
    checkCudaErrors(cudaMalloc((void**) &dev_array, 1*sizeof(int)));
    checkCudaErrors(cudaMemcpy(dev_array,array,1*sizeof(int),cudaMemcpyHostToDevice));
    cumulativeSum<<<1,1>>>(dev_array,1);
    cudaMemcpy(array,dev_array,1*sizeof(int),cudaMemcpyDeviceToHost);
    cudaDeviceSynchronize();
    cudaFree(dev_array);
    for (int i = 0; i < 1; i++)  {
        if (array[i] != expected[i])  {
            printf("failed test %d",1);
            printf("expected array: {%d}",expected[0]);
            printf("    got: {%d}\n",array[0]);
            break;
        }
    }
}

void CSTest5()  {
    int array[0] = {};
    int expected[0] = {};
    printf("running test on array: []...\n");
    int *dev_array;
    checkCudaErrors(cudaMalloc((void**) &dev_array, 0*sizeof(int)));
    checkCudaErrors(cudaMemcpy(dev_array,array,0*sizeof(int),cudaMemcpyHostToDevice));
    cumulativeSum<<<1,1>>>(dev_array,0);
    cudaMemcpy(array,dev_array,0*sizeof(int),cudaMemcpyDeviceToHost);
    cudaDeviceSynchronize();
    cudaFree(dev_array);
    for (int i = 0; i < 0; i++)  {
        if (array[i] != expected[i])  {
            printf("failed test %d",1);
            printf("expected array: {}",expected[0]);
            printf("    got: {}\n");
            break;
        }
    }
}

#endif // TIM_CU

