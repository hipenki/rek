<?php

class Admin_ThesaurusController extends Whale_Controller_Action
{

    public function init()
    {
        parent::init();
    }

    public function indexAction()
    {
        $colorService = new Catalog_Model_ColorService();
        $surfaceService = new Catalog_Model_SurfaceService();
        $countryService = new Catalog_Model_CountryService();
        $patternService = new Catalog_Model_PatternService();
        $collectionService = new Catalog_Model_CollectionService();

        $this->view->thesaurus = array(
            'colors' => array(
                'items' => $colorService->fetchAll(),
                'title' => 'Цвет',
                'controller' => 'color',
            ),
            'collections' => array(
                'items' => $collectionService->fetchAll(),
                'title' => 'Коллекция',
                'controller' => 'collection',
            ),
            'surfaces' => array(
                'items' => $surfaceService->fetchAll(),
                'title' => 'Поверхность',
                'controller' => 'surface',
            ),
            'countries' => array(
                'items' => $countryService->fetchAll(),
                'title' => 'Страна',
                'controller' => 'country',
            ),
            'patterns' => array(
                'items' => $patternService->fetchAll(),
                'title' => 'Рисунок',
                'controller' => 'pattern',
            ),
        );
    }


}

