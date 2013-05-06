<?php

class Whale_Router_Page extends Zend_Controller_Router_Route {

    public $db = null;

    public static function getInstance(Zend_Config $config)
    {
        $reqs = ($config->reqs instanceof Zend_Config) ? $config->reqs->toArray() : array();
        $defs = ($config->defaults instanceof Zend_Config) ? $config->defaults->toArray() : array();
        return new self($config->route, $defs, $reqs);
    }

    public function match($path, $partial = false)
    {
        if ($path instanceof Zend_Controller_Request_Http) {
            $path = $path->getPathInfo();
        }

        if (!$partial) {
            $path = trim($path, $this->_urlDelimiter);
        }

        $db = Zend_Db_Table::getDefaultAdapter();

        $sql = "SELECT p.id, array_to_string(array_agg(a.page_url ORDER BY a.path), '/') AS url
FROM page As p INNER JOIN page AS a
    ON (a.path @> p.path)
GROUP BY p.id, p.path, p.page_url
ORDER BY url";

        $select = $db->select()->from(
            array('p' => 'page'),
            array('url' => "array_to_string(array_agg(a.page_url ORDER BY a.path), '/')")
        )->joinInner(
            array('a' => 'page'),
            'a.path @> p.path',
            array()
        )->group(
            'p.id',
            'p.path',
            'p.page_url'
        );

        $nextSelect = $db->select()->from(array('s' => $select), '*')->where('url = ?', $path);
        $result = $nextSelect->query()->fetch();
//        Whale_Log::log($result);
        return empty($result) ? false : array('page' => $result) + $this->_defaults;
    }

    public function assemble($data = array(), $reset = false, $encode = false)
    {
        return $data['page_url'];
    }
}