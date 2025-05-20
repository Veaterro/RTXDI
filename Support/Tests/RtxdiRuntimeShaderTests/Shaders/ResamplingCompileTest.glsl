/***************************************************************************
 # Copyright (c) 2020-2023, NVIDIA CORPORATION.  All rights reserved.
 #
 # NVIDIA CORPORATION and its licensors retain all intellectual property
 # and proprietary rights in and to this software, related documentation
 # and any modifications thereto.  Any use, reproduction, disclosure or
 # distribution of this software and related documentation without an express
 # license agreement from NVIDIA CORPORATION is strictly prohibited.
 **************************************************************************/

// This shader file is intended for testing the RTXDI header files 
// for GLSL compatibility.

#version 460
#extension GL_GOOGLE_include_directive : enable

// Subgroup arithmetic is used in the boiling filter
#extension GL_KHR_shader_subgroup_arithmetic : enable
#extension GL_KHR_shader_subgroup_ballot : enable

#define RTXDI_GLSL
#define RTXDI_REGIR_MODE RTXDI_REGIR_ONION

#include "rtxdi/DI/ReSTIRDIParameters.h"
#include "rtxdi/GI/ReSTIRGIParameters.h"

#include "RtxdiApplicationBridge/RtxdiApplicationBridge.glsli"

#define RTXDI_ENABLE_BOILING_FILTER
#define RTXDI_BOILING_FILTER_GROUP_SIZE 16

#define RTXDI_RIS_BUFFER u_RisBuffer
#define RTXDI_LIGHT_RESERVOIR_BUFFER u_LightReservoirs
#define RTXDI_NEIGHBOR_OFFSETS_BUFFER t_NeighborOffsets
#define RTXDI_GI_RESERVOIR_BUFFER u_GIReservoirs

#include "rtxdi/LightSampling/PresamplingFunctions.hlsli"
#include "rtxdi/DI/InitialSampling.hlsli"
#include "rtxdi/DI/SpatialResampling.hlsli"
#include "rtxdi/DI/SpatiotemporalResampling.hlsli"
#include "rtxdi/DI/TemporalResampling.hlsli"

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

void main()
{
}
