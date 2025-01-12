#include "../../Config.h"
#include <Graphics/Context.h>
#include "opengl_ColorBufferReaderWithPixelBuffer.h"

using namespace graphics;
using namespace opengl;

ColorBufferReaderWithPixelBuffer::ColorBufferReaderWithPixelBuffer(CachedTexture *_pTexture,
																   CachedBindBuffer *_bindBuffer)
	: ColorBufferReader(_pTexture), m_bindBuffer(_bindBuffer)
{
	_initBuffers();
}


ColorBufferReaderWithPixelBuffer::~ColorBufferReaderWithPixelBuffer()
{
	_destroyBuffers();
}

void ColorBufferReaderWithPixelBuffer::_destroyBuffers()
{
	glDeleteBuffers(m_numPBO, m_PBO);

	for (u32 index = 0; index < m_numPBO; ++index)
		m_PBO[index] = 0;
}

void ColorBufferReaderWithPixelBuffer::_initBuffers()
{
	m_numPBO = config.frameBufferEmulation.copyToRDRAM;
	if (m_numPBO > _maxPBO)
		m_numPBO = _maxPBO;

	// Generate Pixel Buffer Objects
	glGenBuffers(m_numPBO, m_PBO);
	m_curIndex = 0;

	// Initialize Pixel Buffer Objects
	for (u32 i = 0; i < m_numPBO; ++i) {
		m_bindBuffer->bind(Parameter(GL_PIXEL_PACK_BUFFER), ObjectHandle(m_PBO[i]));
		glBufferData(GL_PIXEL_PACK_BUFFER, m_pTexture->textureBytes, nullptr, GL_DYNAMIC_READ);
	}
	m_bindBuffer->bind(Parameter(GL_PIXEL_PACK_BUFFER), ObjectHandle::null);
}

const u8 * ColorBufferReaderWithPixelBuffer::_readPixels(const ReadColorBufferParams& _params, u32& _heightOffset,
	u32& _stride)
{
	GLenum format = GLenum(_params.colorFormat);
	GLenum type = GLenum(_params.colorType);

	m_bindBuffer->bind(Parameter(GL_PIXEL_PACK_BUFFER), ObjectHandle(m_PBO[m_curIndex]));
	glReadPixels(_params.x0, _params.y0, m_pTexture->realWidth, _params.height, format, type, 0);
	// If Sync, read pixels from the buffer, copy them to RDRAM.
	// If not Sync, read pixels from the buffer, copy pixels from the previous buffer to RDRAM.
	if (!_params.sync) {
		m_curIndex = (m_curIndex + 1) % m_numPBO;
		m_bindBuffer->bind(Parameter(GL_PIXEL_PACK_BUFFER), ObjectHandle(m_PBO[m_curIndex]));
	}

	_heightOffset = 0;
	_stride = m_pTexture->realWidth;

	return reinterpret_cast<u8*>(glMapBufferRange(GL_PIXEL_PACK_BUFFER, 0,
		m_pTexture->realWidth * _params.height * _params.colorFormatBytes, GL_MAP_READ_BIT));
}

void ColorBufferReaderWithPixelBuffer::cleanUp()
{
	glUnmapBuffer(GL_PIXEL_PACK_BUFFER);
	m_bindBuffer->bind(Parameter(GL_PIXEL_PACK_BUFFER), ObjectHandle::null);
}
