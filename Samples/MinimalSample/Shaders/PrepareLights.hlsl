/***************************************************************************
 # Copyright (c) 2020-2023, NVIDIA CORPORATION.  All rights reserved.
 #
 # NVIDIA CORPORATION and its licensors retain all intellectual property
 # and proprietary rights in and to this software, related documentation
 # and any modifications thereto.  Any use, reproduction, disclosure or
 # distribution of this software and related documentation without an express
 # license agreement from NVIDIA CORPORATION is strictly prohibited.
 **************************************************************************/

#pragma pack_matrix(row_major)

#include "RtxdiApplicationBridge/RAB_LightInfo.hlsli"

#include <donut/shaders/bindless.h>
#include <donut/shaders/binding_helpers.hlsli>
#include <donut/shaders/packing.hlsli>
#include <Rtxdi/Utils/Math.hlsli>
#include "ShaderParameters.h"

VK_PUSH_CONSTANT ConstantBuffer<PrepareLightsConstants> g_Const : register(b0);
RWStructuredBuffer<RAB_LightInfo> u_LightDataBuffer : register(u0);
StructuredBuffer<PrepareLightsTask> t_TaskBuffer : register(t0);
StructuredBuffer<InstanceData> t_InstanceData : register(t2);
StructuredBuffer<GeometryData> t_GeometryData : register(t3);
StructuredBuffer<MaterialConstants> t_MaterialConstants : register(t4);
SamplerState s_MaterialSampler : register(s0);

VK_BINDING(0, 1) ByteAddressBuffer t_BindlessBuffers[] : register(t0, space1);
VK_BINDING(1, 1) Texture2D t_BindlessTextures[] : register(t0, space2);

#include "TriangleLight.hlsli"

bool FindTask(uint dispatchThreadId, out PrepareLightsTask task)
{
    // Use binary search to find the task that contains the current thread's output index:
    //   task.lightBufferOffset <= dispatchThreadId < (task.lightBufferOffset + task.triangleCount)

    int left = 0;
    int right = int(g_Const.numTasks) - 1;

    while (right >= left)
    {
        int middle = (left + right) / 2;
        task = t_TaskBuffer[middle];

        int tri = int(dispatchThreadId) - int(task.lightBufferOffset); // signed

        if (tri < 0)
        {
            // Go left
            right = middle - 1;
        }
        else if (tri < task.triangleCount)
        {
            // Found it!
            return true;
        }
        else
        {
            // Go right
            left = middle + 1;
        }
    }

    return false;
}

[numthreads(256, 1, 1)]
void main(uint dispatchThreadId : SV_DispatchThreadID, uint groupThreadId : SV_GroupThreadID)
{
    PrepareLightsTask task = (PrepareLightsTask)0;

    if (!FindTask(dispatchThreadId, task))
        return;

    uint triangleIdx = dispatchThreadId - task.lightBufferOffset;
    
    RAB_LightInfo lightInfo = (RAB_LightInfo)0;

    {
        InstanceData instance = t_InstanceData[task.instanceIndex];
        GeometryData geometry = t_GeometryData[instance.firstGeometryIndex + task.geometryIndex];
        MaterialConstants material = t_MaterialConstants[geometry.materialIndex];

        ByteAddressBuffer indexBuffer = t_BindlessBuffers[NonUniformResourceIndex(geometry.indexBufferIndex)];
        ByteAddressBuffer vertexBuffer = t_BindlessBuffers[NonUniformResourceIndex(geometry.vertexBufferIndex)];
        
        uint3 indices = indexBuffer.Load3(geometry.indexOffset + triangleIdx * c_SizeOfTriangleIndices);

        float3 positions[3];

        positions[0] = asfloat(vertexBuffer.Load3(geometry.positionOffset + indices[0] * c_SizeOfPosition));
        positions[1] = asfloat(vertexBuffer.Load3(geometry.positionOffset + indices[1] * c_SizeOfPosition));
        positions[2] = asfloat(vertexBuffer.Load3(geometry.positionOffset + indices[2] * c_SizeOfPosition));
        
        positions[0] = mul(instance.transform, float4(positions[0], 1)).xyz;
        positions[1] = mul(instance.transform, float4(positions[1], 1)).xyz;
        positions[2] = mul(instance.transform, float4(positions[2], 1)).xyz;

        float3 radiance = material.emissiveColor;

        if (material.emissiveTextureIndex >= 0 && geometry.texCoord1Offset != ~0u && (material.flags & MaterialFlags_UseEmissiveTexture) != 0)
        {
            Texture2D emissiveTexture = t_BindlessTextures[NonUniformResourceIndex(material.emissiveTextureIndex)];

            // Load the vertex UVs
            float2 uvs[3];
            uvs[0] = asfloat(vertexBuffer.Load2(geometry.texCoord1Offset + indices[0] * c_SizeOfTexcoord));
            uvs[1] = asfloat(vertexBuffer.Load2(geometry.texCoord1Offset + indices[1] * c_SizeOfTexcoord));
            uvs[2] = asfloat(vertexBuffer.Load2(geometry.texCoord1Offset + indices[2] * c_SizeOfTexcoord));

            // Calculate the triangle edges and edge lengths in UV space
            float2 edges[3];
            edges[0] = uvs[1] - uvs[0];
            edges[1] = uvs[2] - uvs[1];
            edges[2] = uvs[0] - uvs[2];

            float3 edgeLengths;
            edgeLengths[0] = length(edges[0]);
            edgeLengths[1] = length(edges[1]);
            edgeLengths[2] = length(edges[2]);

            // Find the shortest edge and the other two (longer) edges
            float2 shortEdge;
            float2 longEdge1;
            float2 longEdge2;

            if (edgeLengths[0] < edgeLengths[1] && edgeLengths[0] < edgeLengths[2])
            {
                shortEdge = edges[0];
                longEdge1 = edges[1];
                longEdge2 = edges[2];
            }
            else if (edgeLengths[1] < edgeLengths[2])
            {
                shortEdge = edges[1];
                longEdge1 = edges[2];
                longEdge2 = edges[0];
            }
            else
            {
                shortEdge = edges[2];
                longEdge1 = edges[0];
                longEdge2 = edges[1];
            }

            // Use anisotropic sampling with the sample ellipse axes parallel to the short edge
            // and the median from the opposite vertex to the short edge.
            // This ellipse is roughly inscribed into the triangle and approximates long or skinny
            // triangles with highly anisotropic sampling, and is mostly round for usual triangles.
            float2 shortGradient = shortEdge * (2.0 / 3.0);
            float2 longGradient = (longEdge1 + longEdge2) / 3.0;

            // Sample
            float2 centerUV = (uvs[0] + uvs[1] + uvs[2]) / 3.0;
            float3 emissiveMask = emissiveTexture.SampleGrad(s_MaterialSampler, centerUV, shortGradient, longGradient).rgb;

            radiance *= emissiveMask;
        }

        radiance.rgb = max(0, radiance.rgb);

        TriangleLight triLight;
        triLight.base = positions[0];
        triLight.edge1 = positions[1] - positions[0];
        triLight.edge2 = positions[2] - positions[0];
        triLight.radiance = radiance;

        lightInfo = Store(triLight);
    }

    uint lightBufferPtr = task.lightBufferOffset + triangleIdx;
    u_LightDataBuffer[lightBufferPtr] = lightInfo;
}
