/**************************************************************************
**
**   SNOW - CS224 BROWN UNIVERSITY
**
**   scenenode.cpp
**   Author: mliberma
**   Created: 8 Apr 2014
**
**************************************************************************/

#include <GL/gl.h>

#ifndef GLM_FORCE_RADIANS
    #define GLM_FORCE_RADIANS
#endif
#include "glm/gtc/type_ptr.hpp"

#include "common/common.h"
#include "common/renderable.h"
#include "scene/scenenode.h"

SceneNode::SceneNode( Type type )
    : m_parent(NULL),
      m_ctm(1.f),
      m_ctmDirty(true),
      m_transform(1.f),
      m_renderable(NULL),
      m_type(type)
{
}

SceneNode::~SceneNode()
{
    SAFE_DELETE( m_renderable );
    clearChildren();
}

void
SceneNode::clearChildren()
{
    for ( int i = 0; i < m_children.size(); ++i )
        SAFE_DELETE( m_children[i] );
    m_children.clear();
}

void
SceneNode::addChild( SceneNode *child )
{
    m_children += child;
    child->m_parent = this;
    child->setCTMDirty();
}

void
SceneNode::deleteChild( SceneNode *child )
{
    int index = m_children.indexOf( child );
    if ( index != -1 ) {
        SceneNode *child = m_children[index];
        SAFE_DELETE( child );
        m_children.removeAt( index );
    }
}

void
SceneNode::setRenderable( Renderable *renderable )
{
    SAFE_DELETE( m_renderable );
    m_renderable = renderable;
}

void
SceneNode::renderOpaque()
{
    glMatrixMode( GL_MODELVIEW );
    glPushMatrix();
    glMultMatrixf( glm::value_ptr(getCTM()) );
    if ( m_renderable && !isTransparent() ) m_renderable->render();
    glPopMatrix();
    for ( int i = 0; i < m_children.size(); ++i )
        m_children[i]->renderOpaque();
}

void
SceneNode::renderTransparent()
{
    glMatrixMode( GL_MODELVIEW );
    glPushMatrix();
    glMultMatrixf( glm::value_ptr(getCTM()) );
    glPopMatrix();
    if ( m_renderable && isTransparent() ) m_renderable->render();
    for ( int i = 0; i < m_children.size(); ++i )
        m_children[i]->renderTransparent();
}

void
SceneNode::applyTransformation( const glm::mat4 &transform )
{
    m_transform = transform * m_transform;
    setCTMDirty();
}

glm::mat4
SceneNode::getCTM()
{
    if ( m_ctmDirty ) {
        glm::mat4 pCtm = ( m_parent ) ? m_parent->getCTM() : glm::mat4();
        m_ctm = pCtm * m_transform;
        m_ctmDirty = false;
    }
    return m_ctm;
}

void
SceneNode::setCTMDirty()
{
    for ( int i = 0; i < m_children.size(); ++i ) {
        m_children[i]->setCTMDirty();
    }
    m_ctmDirty = true;
    m_bboxDirty = true;
}

BBox
SceneNode::getBBox()
{
    if ( m_bboxDirty ) {
        if ( hasRenderable() ) {
            m_bbox = m_renderable->getBBox( getCTM() );
        } else {
            m_bbox = BBox();
        }
        m_bboxDirty = false;
    }
    return m_bbox;
}
