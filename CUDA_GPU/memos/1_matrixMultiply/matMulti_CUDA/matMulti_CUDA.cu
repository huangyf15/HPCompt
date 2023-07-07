#include <cuda_runtime.h>
#include <device_launch_parameters.h>
#include <iostream>
#include <fstream>
#include <Windows.h>
#include <io.h>
#include <string>
#include <math.h>
#include <time.h>
#include <chrono>

using namespace std;
using namespace chrono;

#define DEBUGMODE 1
#define RUNMODE 0
#define PRECISION 1e-5

// totalWidth/BLOCK_WIDTH should be integer
// -- shared memory is used and no elsecase
#define BLOCK_WIDTH 8
int totalWidth = 2048;

void random_ints(int* a, int n){ for (int i = 0; i < n; ++i)	a[i] = rand()%10;}

string getCurrTimeStr();

void mulMatrixOnHost(int* M, int* N, int* P, int totalWidth);

inline int map2MatrixEleNo(int rowNo, int colNo, int height) { return rowNo * height + colNo; }

void printResMatrix(string info, float seconds, int* mat, int totalWidth);

// can only deal with matrix size < 32 * 32
__global__ void mulMatrixKernel_singleBlock(int* d_M, int* d_N, int* d_P, int totalWidth)
{
	int tx = threadIdx.x;
	int ty = threadIdx.y;

	int Pvalue = 0;

	for (int k = 0; k < totalWidth; ++k)
	{
		int d_Mele = d_M[ty * totalWidth + k];
		int d_Nele = d_N[k * totalWidth + tx];
		Pvalue += d_Mele * d_Nele;
	}
	d_P[ty * totalWidth + tx] = Pvalue;
}

__global__ void mulMatrixKernel_globalMem(int* d_M, int* d_N, int* d_P, int totalWidth)
{
	int row = blockIdx.y * blockDim.y + threadIdx.y;
	int col = blockIdx.x * blockDim.x + threadIdx.x;

	int Pvalue = 0;

	for (int k = 0; k < totalWidth; ++k)
	{
		Pvalue += d_M[row * totalWidth + k] * d_N[k * totalWidth + col];
	}

	d_P[row * totalWidth + col] = Pvalue;
}

__global__ void mulMatrixKernel_sharedMem(int* d_M, int* d_N, int* d_P, int totalWidth)
{
  __shared__ int d_Ms[BLOCK_WIDTH][BLOCK_WIDTH];
  __shared__ int d_Ns[BLOCK_WIDTH][BLOCK_WIDTH];

  int bx = blockIdx.x;  int by = blockIdx.y;
  int tx = threadIdx.x; int ty = threadIdx.y;
	int row = by * BLOCK_WIDTH + ty;
	int col = bx * BLOCK_WIDTH + tx;

	int Pvalue = 0;

  for (int m = 0; m < totalWidth/BLOCK_WIDTH; ++m)
  {
    d_Ms[ty][tx] = d_M[row*totalWidth + (m*BLOCK_WIDTH + tx)];
    d_Ns[ty][tx] = d_N[col + (m*BLOCK_WIDTH + ty)*totalWidth];
    __syncthreads();
    for (int k = 0; k < BLOCK_WIDTH; ++k)
    {
      Pvalue += d_Ms[ty][k] * d_Ns[k][tx];
      __syncthreads();
    }
  }

	d_P[row * totalWidth + col] = Pvalue;
}

int main(int argc, char** argv)
{
  int thisTest;
  if (argc > 1) 
  {
    thisTest = atoi(argv[1]);
  }
  else
  {
    thisTest = 1;
  }

	static string testName = "shared memory effect on matMulti_CUDA";
  string folderPath = "res_matMulti_CUDA_gs";
	static string opFileName = folderPath+"/out_gs_w"+to_string(totalWidth)\
                                   +"_b"+to_string(BLOCK_WIDTH)+".log";

  if (~_access(folderPath.c_str(), 0))
  {
    string command;
    command = "mkdir " + folderPath;  
    system(command.c_str());
  }
	ofstream fout(opFileName);
	streambuf* oldclog;
	oldclog = clog.rdbuf(fout.rdbuf());

	clog << "Title: " << testName << "\n"
		<< "Current time: " << getCurrTimeStr() << " ms\n\n"
		<< "Init matrices: Width = " << totalWidth << "\n"
		<< "CUDA blocksize = " << BLOCK_WIDTH << "\n" << endl;

	int totalEleNum = totalWidth * totalWidth;
	int* matA, * matB, * matC_g, * matC_s, * matCRef;
	int size_of_matrix = totalEleNum * sizeof(int);

	matA = (int*)malloc(size_of_matrix); random_ints(matA, totalEleNum);
	matB = (int*)malloc(size_of_matrix); random_ints(matB, totalEleNum);
	matC_g = (int*)malloc(size_of_matrix); random_ints(matC_g, totalEleNum);
	matC_s = (int*)malloc(size_of_matrix); random_ints(matC_s, totalEleNum);
	matCRef = (int*)malloc(size_of_matrix); random_ints(matCRef, totalEleNum);

	// CPU compt
	auto start = system_clock::now();
	mulMatrixOnHost(matA, matB, matCRef, totalWidth);
	auto end = system_clock::now();
	auto duration = duration_cast<microseconds>(end - start);
	float seconds = float(duration.count()) * microseconds::period::num \
		/ microseconds::period::den;
  clog << "--hostFunc() elapsed " << seconds << " s..\n\n";

	// GPU compt: preparation
	int* d_matA, * d_matB, * d_matC_g, * d_matC_s;

	dim3 dimBlock(BLOCK_WIDTH, BLOCK_WIDTH);
	dim3 dimGrid((totalWidth + dimBlock.x - 1) / dimBlock.x, \
               (totalWidth + dimBlock.y - 1) / dimBlock.y);

	cudaMalloc((void**)&d_matA, size_of_matrix);
	cudaMalloc((void**)&d_matB, size_of_matrix);

	cudaMemcpy(d_matA, matA, size_of_matrix, cudaMemcpyHostToDevice);
	cudaMemcpy(d_matB, matB, size_of_matrix, cudaMemcpyHostToDevice);

  // use global memory
	start = system_clock::now();

	cudaMalloc((void**)&d_matC_g, size_of_matrix);
	mulMatrixKernel_globalMem << <dimGrid, dimBlock >> > (d_matA, d_matB, d_matC_g, totalWidth);
	cudaMemcpy(matC_g, d_matC_g, size_of_matrix, cudaMemcpyDeviceToHost);

	end = system_clock::now();
	duration = duration_cast<microseconds>(end - start);
	seconds = float(duration.count()) * microseconds::period::num \
		/ microseconds::period::den;
  clog << "--GPU_gFunc() elapsed " << seconds << " s..\n\n";

  // use shared memory
	start = system_clock::now();

	cudaMalloc((void**)&d_matC_s, size_of_matrix);
	mulMatrixKernel_sharedMem << <dimGrid, dimBlock >> > (d_matA, d_matB, d_matC_s, totalWidth);
	cudaMemcpy(matC_s, d_matC_s, size_of_matrix, cudaMemcpyDeviceToHost);

	end = system_clock::now();
	duration = duration_cast<microseconds>(end - start);
	seconds = float(duration.count()) * microseconds::period::num \
		/ microseconds::period::den;
  clog << "--GPU_sFunc() elapsed " << seconds << " s..\n\n";

  // check device results
  for (int i = 0; i < totalEleNum; ++i)
  {
    if (fabs(matCRef[i] - matC_g[i]) > PRECISION)
    {
      fprintf(stderr,"Result verification failed (GPU_g) at element %d\n",i);
      exit(EXIT_FAILURE);
    }
    else if (fabs(matCRef[i] - matC_s[i]) > PRECISION)
    {
      fprintf(stderr,"Result verification failed (GPU_s) at element %d\n",i);
      exit(EXIT_FAILURE);
    }
  }

  // free device global memory
	cudaFree(d_matA);
	cudaFree(d_matB);
	cudaFree(d_matC_g);
	cudaFree(d_matC_s);

  // free host memory
	free(matA);
	free(matB);
	free(matC_g);
	free(matC_s);
	free(matCRef);

  return 0;
}

string getCurrTimeStr()
{
	system_clock::time_point t = system_clock::now();
	milliseconds ms = duration_cast<milliseconds>(t.time_since_epoch());
	char time_string[128];
	time_t curtm = time(NULL);
	struct tm tm;
	localtime_s(&tm, &curtm);
	sprintf_s(time_string, "%04d-%02d-%02d %02d:%02d:%02d %03lld ", \
		tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday, tm.tm_hour, \
		tm.tm_min, tm.tm_sec, ms.count() % 1000);
	return time_string;
}

void mulMatrixOnHost(int* M, int* N, int* P, int totalWidth)
{
	for (int i = 0; i < totalWidth; ++i)
	{
		for (int j = 0; j < totalWidth; ++j)
		{
			int sum = 0;
			for (int k = 0; k < totalWidth; ++k)
			{
				sum += M[map2MatrixEleNo(i, k, totalWidth)] * \
					N[map2MatrixEleNo(k, j, totalWidth)];
			}
			P[map2MatrixEleNo(i, j, totalWidth)] = sum;
		}
	}
}

void printResMatrix(string info, float seconds, int* mat, int totalWidth)
{
	clog << "*** Using " << info << ": cost "
		<< seconds << " s" << endl;
	int outputWidth = min(totalWidth, 10);
	for (int i = 0; i < outputWidth; i++)
	{
		for (int j = 0; j < outputWidth; j++)
		{
			clog << mat[map2MatrixEleNo(i, j, totalWidth)] << "\t";
		}
		clog << endl << endl;
	}
}