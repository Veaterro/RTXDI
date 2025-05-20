/***************************************************************************
 # Copyright (c) 2020-2023, NVIDIA CORPORATION.  All rights reserved.
 #
 # NVIDIA CORPORATION and its licensors retain all intellectual property
 # and proprietary rights in and to this software, related documentation
 # and any modifications thereto.  Any use, reproduction, disclosure or
 # distribution of this software and related documentation without an express
 # license agreement from NVIDIA CORPORATION is strictly prohibited.
 **************************************************************************/

#pragma once

#include <nvrhi/nvrhi.h>

namespace rtxdi
{
    class RISBufferSegmentAllocator;
    class ReSTIRDIContext;
    class ImportanceSamplingContext;
}

class RtxdiResources
{
public:
    nvrhi::BufferHandle TaskBuffer;
    nvrhi::BufferHandle PrimitiveLightBuffer;
    nvrhi::BufferHandle LightDataBuffer;
    nvrhi::BufferHandle GeometryInstanceToLightBuffer;
    nvrhi::BufferHandle LightIndexMappingBuffer;
    nvrhi::BufferHandle RisBuffer;
    nvrhi::BufferHandle RisLightDataBuffer;
    nvrhi::BufferHandle NeighborOffsetsBuffer;
    nvrhi::BufferHandle LightReservoirBuffer;
    nvrhi::BufferHandle SecondaryGBuffer;
    nvrhi::TextureHandle EnvironmentPdfTexture;
    nvrhi::TextureHandle LocalLightPdfTexture;
    nvrhi::BufferHandle GIReservoirBuffer;

    RtxdiResources(
        nvrhi::IDevice* device, 
        const rtxdi::ReSTIRDIContext& context,
        const rtxdi::RISBufferSegmentAllocator& risBufferSegmentAllocator,
        uint32_t maxEmissiveMeshes,
        uint32_t maxEmissiveTriangles,
        uint32_t maxPrimitiveLights,
        uint32_t maxGeometryInstances,
        uint32_t environmentMapWidth,
        uint32_t environmentMapHeight);

    void InitializeNeighborOffsets(nvrhi::ICommandList* commandList, uint32_t neighborOffsetCount);

    uint32_t GetMaxEmissiveMeshes() const;
    uint32_t GetMaxEmissiveTriangles() const;
    uint32_t GetMaxPrimitiveLights() const;
    uint32_t GetMaxGeometryInstances() const;

private:
    bool m_neighborOffsetsInitialized = false;
    uint32_t m_maxEmissiveMeshes = 0;
    uint32_t m_maxEmissiveTriangles = 0;
    uint32_t m_maxPrimitiveLights = 0;
    uint32_t m_maxGeometryInstances = 0;
};
